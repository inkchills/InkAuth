/**
 * KeePass KDBX4 importer — port of Stratum.Core KeePassBackupConverter.
 *
 * export async function decryptKeePassKdbx(data, password): Promise<string[]>
 *   → otpauth/motp URIs from String Key=="otp" (excludes History + recycle bin)
 *
 * Supported:
 *   Format: KDBX v4 only
 *   KDF: Argon2id, Argon2d (@ohos-rs/argon2 hashRaw), AES-KDF (AES-256-ECB)
 *   Outer: AES-256-CBC/PKCS7, ChaCha20 (IETF)
 *   Compression: None, GZip (pure ArkTS inflate)
 *   Inner protected stream: ChaCha20, Salsa20
 *   HMAC-SHA256 block auth + SHA256 header integrity
 *
 * Unsupported: Twofish outer cipher; KDBX major ≠ 4.
 */

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { hashRaw, hashRawSync } from '@ohos-rs/argon2';

// ── Constants ──────────────────────────────────────────────────────────────

const HEADER_SIGNATURE_1: number = 0x9AA2D903;
const HEADER_SIGNATURE_2: number = 0xB54BFB67;
const END_OF_HEADER: number[] = [0x0D, 0x0A, 0x0D, 0x0A];
const KEY_LENGTH: number = 32;
const HEADER_HASH_LENGTH: number = 32;
const AUTH_SEED: number[] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF];
const SALSA_IV: number[] = [0xE8, 0x30, 0x09, 0x4B, 0x97, 0x20, 0x5D, 0x2A];

const AES_UUID: number[] = [
  0x31, 0xC1, 0xF2, 0xE6, 0xBF, 0x71, 0x43, 0x50,
  0xBE, 0x58, 0x05, 0x21, 0x6A, 0xFC, 0x5A, 0xFF
];
const CHACHA_UUID: number[] = [
  0xD6, 0x03, 0x8A, 0x2B, 0x8B, 0x6F, 0x4C, 0xB5,
  0xA5, 0x24, 0x33, 0x9A, 0x31, 0xDB, 0xB5, 0x9A
];
const TWOFISH_UUID: number[] = [
  0xAD, 0x68, 0xF2, 0x9F, 0x57, 0x6F, 0x4B, 0xB9,
  0xA3, 0x6A, 0xD4, 0x7A, 0xF9, 0x65, 0x34, 0x6C
];
const AES_KDF_UUID: number[] = [
  0xC9, 0xD9, 0xF3, 0x9A, 0x62, 0x8A, 0x44, 0x60,
  0xBF, 0x74, 0x0D, 0x08, 0xC1, 0x8A, 0x4F, 0xEA
];
const ARGON2D_UUID: number[] = [
  0xEF, 0x63, 0x6D, 0xDF, 0x8C, 0x29, 0x44, 0x4B,
  0x91, 0xF7, 0xA9, 0xA4, 0x03, 0xE3, 0x0A, 0x0C
];
const ARGON2ID_UUID: number[] = [
  0x9E, 0x29, 0x8B, 0x19, 0x56, 0xDB, 0x47, 0x73,
  0xB2, 0x3D, 0xFC, 0x3E, 0xC6, 0xF0, 0xA1, 0xE6
];

const CHACHA_CONST: number[] = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574];
const SALSA_SIGMA: number[] = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574];
const DOUBLE_ROUNDS: number = 10;
const BLOCK64: number = 64;

enum OuterCipher { Aes256 = 0, ChaCha20 = 1, TwoFish = 2 }
enum InnerCipher { Salsa20 = 2, ChaCha20 = 3 }
enum CompressionAlg { None = 0, GZip = 1 }

interface Argon2RawOptions {
  salt: ArrayBuffer;
  algorithm: number;
  version: number;
  timeCost: number;
  memoryCost: number;
  parallelism: number;
  outputLen: number;
}

type Argon2HashRawFn = (password: string | ArrayBuffer, options: Argon2RawOptions) => Promise<ArrayBuffer>;
type Argon2HashRawSyncFn = (password: string | ArrayBuffer, options: Argon2RawOptions) => ArrayBuffer;

interface ProtectedStream {
  process(input: Uint8Array): Uint8Array;
}

class BinaryReader {
  readonly data: Uint8Array;
  pos: number = 0;

  constructor(data: Uint8Array) {
    this.data = data;
  }

  get length(): number {
    return this.data.length;
  }

  readByte(): number {
    if (this.pos >= this.data.length) {
      throw new Error('Unexpected end of data');
    }
    return this.data[this.pos++];
  }

  readBytes(count: number): Uint8Array {
    if (count < 0 || this.pos + count > this.data.length) {
      throw new Error('Unexpected end of data');
    }
    const slice: Uint8Array = this.data.subarray(this.pos, this.pos + count);
    this.pos += count;
    return slice;
  }

  readUInt16(): number {
    const b: Uint8Array = this.readBytes(2);
    return (b[0] | (b[1] << 8)) >>> 0;
  }

  readUInt32(): number {
    const b: Uint8Array = this.readBytes(4);
    return (b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)) >>> 0;
  }

  readInt32(): number {
    return this.readUInt32() | 0;
  }
}

class VariantDictionary {
  private readonly bytesMap: Map<string, Uint8Array> = new Map<string, Uint8Array>();
  private readonly numberMap: Map<string, number> = new Map<string, number>();

  addBytes(name: string, value: Uint8Array): void {
    this.bytesMap.set(name, value);
  }

  addNumber(name: string, value: number): void {
    this.numberMap.set(name, value);
  }

  getBytes(name: string): Uint8Array {
    const v: Uint8Array | undefined = this.bytesMap.get(name);
    if (v === undefined) {
      throw new Error(`VariantDictionary missing bytes: ${name}`);
    }
    return v;
  }

  getUInt64(name: string): number {
    const v: number | undefined = this.numberMap.get(name);
    if (v === undefined) {
      throw new Error(`VariantDictionary missing u64: ${name}`);
    }
    return v;
  }

  getUInt32(name: string): number {
    const v: number | undefined = this.numberMap.get(name);
    if (v === undefined) {
      throw new Error(`VariantDictionary missing u32: ${name}`);
    }
    return v >>> 0;
  }
}

class Header {
  majorVersion: number = 0;
  minorVersion: number = 0;
  encryptionAlgorithm: OuterCipher = OuterCipher.Aes256;
  compressionAlgorithm: CompressionAlg = CompressionAlg.None;
  masterSalt: Uint8Array = new Uint8Array(0);
  encryptionIv: Uint8Array = new Uint8Array(0);
  kdfParameters: VariantDictionary = new VariantDictionary();
  integrityHash: Uint8Array = new Uint8Array(0);
  authenticityHash: Uint8Array = new Uint8Array(0);
  bytes: Uint8Array = new Uint8Array(0);
}

class KeepassDatabase {
  innerEncryptionAlgorithm: InnerCipher = InnerCipher.ChaCha20;
  innerEncryptionKey: Uint8Array = new Uint8Array(0);
  xml: string = '';
}

interface StringContext {
  key: string;
  parentElement: string;
  groupUuid: string;
}

interface HuffmanTable {
  bits: number[];
  symbols: number[];
  maxBits: number;
}

interface DynamicTables {
  lit: HuffmanTable;
  dist: HuffmanTable;
}

// ── Public API ─────────────────────────────────────────────────────────────

/**
 * Decrypt a KeePass KDBX4 database and return otpauth/motp URI strings
 * from String fields with Key == "otp" (excluding History and recycle bin).
 */
export async function decryptKeePassKdbx(data: Uint8Array, password: string): Promise<string[]> {
  const reader: BinaryReader = new BinaryReader(data);
  const header: Header = readHeader(reader);

  const transformedKey: Uint8Array = await deriveKey(header.kdfParameters, password);
  await verifyHeader(header, transformedKey);

  const masterKey: Uint8Array = await sha256(concatBytes([header.masterSalt, transformedKey]));
  const payload: Uint8Array = await getDecryptedPayload(reader, header, masterKey, transformedKey);
  const database: KeepassDatabase = readDatabase(payload);
  return await getUris(database);
}

// ── Header ─────────────────────────────────────────────────────────────────

function readHeader(reader: BinaryReader): Header {
  const signature1: number = reader.readUInt32();
  const signature2: number = reader.readUInt32();
  if (signature1 !== HEADER_SIGNATURE_1 || signature2 !== HEADER_SIGNATURE_2) {
    throw new Error('Not a KeePass file');
  }

  const header: Header = new Header();
  header.minorVersion = reader.readUInt16();
  header.majorVersion = reader.readUInt16();
  if (header.majorVersion !== 4) {
    throw new Error('Only version 4 KDBX files are supported');
  }

  while (reader.pos < reader.length) {
    const id: number = reader.readByte();
    const messageSize: number = reader.readInt32();
    if (messageSize < 0) {
      throw new Error('Invalid header field size');
    }
    const message: Uint8Array = reader.readBytes(messageSize);

    if (id === 0) {
      if (!bytesEqualArr(message, END_OF_HEADER)) {
        throw new Error('Expected end of header sequence');
      }
      header.bytes = copyBytes(reader.data.subarray(0, reader.pos));
      header.integrityHash = copyBytes(reader.readBytes(HEADER_HASH_LENGTH));
      header.authenticityHash = copyBytes(reader.readBytes(HEADER_HASH_LENGTH));
      return header;
    }

    if (id === 2) {
      if (bytesEqualArr(message, AES_UUID)) {
        header.encryptionAlgorithm = OuterCipher.Aes256;
      } else if (bytesEqualArr(message, CHACHA_UUID)) {
        header.encryptionAlgorithm = OuterCipher.ChaCha20;
      } else if (bytesEqualArr(message, TWOFISH_UUID)) {
        header.encryptionAlgorithm = OuterCipher.TwoFish;
      } else {
        throw new Error('Unknown encryption algorithm');
      }
    } else if (id === 3) {
      header.compressionAlgorithm = message[0] as CompressionAlg;
    } else if (id === 4) {
      header.masterSalt = copyBytes(message);
    } else if (id === 7) {
      header.encryptionIv = copyBytes(message);
    } else if (id === 11) {
      header.kdfParameters = readVariantDictionary(message);
    }
  }

  throw new Error('Incomplete header');
}

function readVariantDictionary(message: Uint8Array): VariantDictionary {
  const reader: BinaryReader = new BinaryReader(message);
  const minorVersion: number = reader.readByte();
  const majorVersion: number = reader.readByte();
  if (majorVersion > 1 || minorVersion > 0) {
    throw new Error(
      `Only version 1.0 variant dictionaries are supported. Got ${majorVersion}.${minorVersion}`
    );
  }

  const dictionary: VariantDictionary = new VariantDictionary();
  while (reader.pos < reader.length) {
    const type: number = reader.readByte();
    if (type === 0) {
      break;
    }
    const nameLength: number = reader.readInt32();
    const name: string = utf8Decode(reader.readBytes(nameLength));
    const valueLength: number = reader.readInt32();

    if (type === 0x04) {
      dictionary.addNumber(name, reader.readUInt32());
    } else if (type === 0x05) {
      dictionary.addNumber(name, readUInt64LE(reader));
    } else if (type === 0x08) {
      reader.readByte(); // boolean — unused by this importer
    } else if (type === 0x0C) {
      dictionary.addNumber(name, reader.readInt32());
    } else if (type === 0x0D) {
      dictionary.addNumber(name, readUInt64LE(reader));
    } else if (type === 0x18) {
      reader.readBytes(valueLength); // string — unused by this importer
    } else if (type === 0x42) {
      dictionary.addBytes(name, copyBytes(reader.readBytes(valueLength)));
    } else {
      reader.readBytes(valueLength);
    }
  }
  return dictionary;
}

function readUInt64LE(reader: BinaryReader): number {
  const lo: number = reader.readUInt32();
  const hi: number = reader.readUInt32();
  return lo + hi * 0x100000000;
}

// ── KDF ────────────────────────────────────────────────────────────────────

async function deriveKey(kdfParameters: VariantDictionary, password: string): Promise<Uint8Array> {
  const passwordBytes: Uint8Array = utf8Encode(password);
  const compositeKey: Uint8Array = await sha256(await sha256(passwordBytes));
  const kdfUuid: Uint8Array = kdfParameters.getBytes('$UUID');

  if (bytesEqualArr(kdfUuid, AES_KDF_UUID)) {
    const salt: Uint8Array = kdfParameters.getBytes('S');
    const rounds: number = kdfParameters.getUInt64('R');
    let transformedKey: Uint8Array = copyBytes(compositeKey);
    for (let i: number = 0; i < rounds; i++) {
      transformedKey = await aesEcbEncrypt(salt, transformedKey);
    }
    return await sha256(transformedKey);
  }

  const isArgon2d: boolean = bytesEqualArr(kdfUuid, ARGON2D_UUID);
  const isArgon2id: boolean = !isArgon2d && bytesEqualArr(kdfUuid, ARGON2ID_UUID);
  if (!isArgon2d && !isArgon2id) {
    throw new Error('Unknown key derivation function');
  }

  const salt: Uint8Array = kdfParameters.getBytes('S');
  const iterations: number = kdfParameters.getUInt64('I');
  const memory: number = kdfParameters.getUInt64('M');
  const parallelism: number = kdfParameters.getUInt32('P');
  // Android Konscious MemorySize = memory/1024 (KiB); M in KDBX is bytes
  return await argon2Raw(
    compositeKey,
    salt,
    isArgon2d ? 0 : 2,
    iterations,
    Math.floor(memory / 1024),
    parallelism,
    KEY_LENGTH
  );
}

async function argon2Raw(
  password: Uint8Array,
  salt: Uint8Array,
  algorithm: number,
  timeCost: number,
  memoryCost: number,
  parallelism: number,
  outputLen: number
): Promise<Uint8Array> {
  const passwordBuf: ArrayBuffer =
    password.buffer.slice(password.byteOffset, password.byteOffset + password.byteLength) as ArrayBuffer;
  const saltBuf: ArrayBuffer =
    salt.buffer.slice(salt.byteOffset, salt.byteOffset + salt.byteLength) as ArrayBuffer;

  const options: Argon2RawOptions = {
    salt: saltBuf,
    algorithm: algorithm,
    version: 1,
    timeCost: timeCost,
    memoryCost: memoryCost,
    parallelism: parallelism,
    outputLen: outputLen
  };

  const hashRawFn: Argon2HashRawFn | undefined = hashRaw as Argon2HashRawFn | undefined;
  if (hashRawFn) {
    return new Uint8Array(await hashRawFn(passwordBuf, options));
  }
  const hashRawSyncFn: Argon2HashRawSyncFn | undefined = hashRawSync as Argon2HashRawSyncFn | undefined;
  if (hashRawSyncFn) {
    return new Uint8Array(hashRawSyncFn(passwordBuf, options));
  }
  throw new Error('argon2 raw hash function not available');
}

// ── Header verify ──────────────────────────────────────────────────────────

async function verifyHeader(header: Header, transformedKey: Uint8Array): Promise<void> {
  const integrityHash: Uint8Array = await sha256(header.bytes);
  if (!bytesEqual(integrityHash, header.integrityHash)) {
    throw new Error('Header integrity check failed');
  }

  const initialAuthHash: Uint8Array = await sha512(
    concatBytes([header.masterSalt, transformedKey, new Uint8Array([1])])
  );
  const authKey: Uint8Array = await sha512(
    concatBytes([new Uint8Array(AUTH_SEED), initialAuthHash])
  );
  const authHash: Uint8Array = await hmacSha256(authKey, header.bytes);
  if (!constantTimeEqual(authHash, header.authenticityHash)) {
    throw new Error('Header authenticity check failed (wrong password?)');
  }
}

// ── Payload ────────────────────────────────────────────────────────────────

async function getDecryptedPayload(
  reader: BinaryReader,
  header: Header,
  masterKey: Uint8Array,
  transformedKey: Uint8Array
): Promise<Uint8Array> {
  if (header.encryptionAlgorithm === OuterCipher.TwoFish) {
    throw new Error('Unsupported outer encryption algorithm: Twofish');
  }

  const blocks: Uint8Array[] = await readRawBlocks(reader, header.masterSalt, transformedKey);
  const parts: Uint8Array[] = [];
  for (let i: number = 0; i < blocks.length; i++) {
    if (blocks[i].length > 0) {
      parts.push(blocks[i]);
    }
  }
  const ciphertext: Uint8Array = concatBytes(parts);

  let decrypted: Uint8Array;
  if (header.encryptionAlgorithm === OuterCipher.Aes256) {
    decrypted = await aesCbcDecrypt(masterKey, header.encryptionIv, ciphertext);
  } else if (header.encryptionAlgorithm === OuterCipher.ChaCha20) {
    if (header.encryptionIv.length !== 12) {
      throw new Error(`ChaCha20 expects 12-byte IV, got ${header.encryptionIv.length}`);
    }
    decrypted = chacha20IetfXor(masterKey, header.encryptionIv, 0, ciphertext);
  } else {
    throw new Error(`Unsupported encryption algorithm ${header.encryptionAlgorithm}`);
  }

  if (header.compressionAlgorithm === CompressionAlg.None) {
    return decrypted;
  }
  if (header.compressionAlgorithm === CompressionAlg.GZip) {
    return gunzip(decrypted);
  }
  throw new Error(`Unsupported compression algorithm ${header.compressionAlgorithm}`);
}

async function readRawBlocks(
  reader: BinaryReader,
  masterSalt: Uint8Array,
  transformedKey: Uint8Array
): Promise<Uint8Array[]> {
  const blocks: Uint8Array[] = [];
  let blockId: number = 0;

  while (reader.pos < reader.length) {
    const expectedAuthHash: Uint8Array = reader.readBytes(32);
    const blockSizeBytes: Uint8Array = copyBytes(reader.readBytes(4));
    const blockSize: number =
      (blockSizeBytes[0] |
        (blockSizeBytes[1] << 8) |
        (blockSizeBytes[2] << 16) |
        (blockSizeBytes[3] << 24)) | 0;
    if (blockSize < 0) {
      throw new Error(`Invalid block size at block ${blockId}`);
    }
    const block: Uint8Array = copyBytes(reader.readBytes(blockSize));

    const key: Uint8Array = await blockHmacKey(blockId, masterSalt, transformedKey);
    const authHash: Uint8Array = await hmacSha256(
      key,
      concatBytes([writeUInt64LE(blockId), blockSizeBytes, block])
    );
    if (!constantTimeEqual(authHash, expectedAuthHash)) {
      throw new Error(`Block ${blockId} MAC does not match`);
    }

    blocks.push(block);
    blockId++;
    if (blockSize === 0) {
      break;
    }
  }
  return blocks;
}

async function blockHmacKey(
  blockId: number,
  masterSalt: Uint8Array,
  transformedKey: Uint8Array
): Promise<Uint8Array> {
  const initialAuthHash: Uint8Array = await sha512(
    concatBytes([masterSalt, transformedKey, new Uint8Array([1])])
  );
  return await sha512(concatBytes([writeUInt64LE(blockId), initialAuthHash]));
}

// ── Inner header + URI extract ─────────────────────────────────────────────

function readDatabase(payload: Uint8Array): KeepassDatabase {
  const reader: BinaryReader = new BinaryReader(payload);
  const database: KeepassDatabase = new KeepassDatabase();

  while (true) {
    const id: number = reader.readByte();
    const size: number = reader.readInt32();
    if (size < 0) {
      throw new Error('Invalid inner header field size');
    }
    if (id === 0) {
      break;
    }
    if (id === 1) {
      database.innerEncryptionAlgorithm = reader.readInt32() as InnerCipher;
    } else if (id === 2) {
      database.innerEncryptionKey = copyBytes(reader.readBytes(size));
    } else if (id === 3) {
      reader.readBytes(size);
    } else {
      throw new Error(`Unknown inner header field ${id}`);
    }
  }

  database.xml = utf8Decode(reader.data.subarray(reader.pos));
  return database;
}

async function getUris(database: KeepassDatabase): Promise<string[]> {
  const stream: ProtectedStream = await createInnerStream(
    database.innerEncryptionAlgorithm,
    database.innerEncryptionKey
  );

  const xml: string = database.xml;
  const recycleBinUuid: string = extractTagText(xml, 'RecycleBinUUID');
  const uris: string[] = [];

  // Document-order //Value — decrypt every Protected field (stream cipher state)
  const valueRegex: RegExp = /<Value(\s[^>]*)?>([^<]*)<\/Value>|<Value(\s[^>]*)?\/>/g;
  let match: RegExpExecArray | null = valueRegex.exec(xml);

  while (match !== null) {
    const fullMatch: string = match[0];
    const attrs: string = match[1] !== undefined ? match[1] : (match[3] !== undefined ? match[3] : '');
    const rawText: string = match[2] !== undefined ? match[2] : '';
    const isProtected: boolean = /Protected\s*=\s*["']True["']/i.test(attrs);

    let value: string;
    if (isProtected) {
      value = utf8Decode(stream.process(base64Decode(rawText)));
    } else {
      value = decodeXmlEntities(rawText);
    }

    const ctx: StringContext | null = findStringContext(xml, match.index, fullMatch.length);
    if (ctx !== null && ctx.key === 'otp' && ctx.parentElement !== 'History' &&
      ctx.groupUuid !== recycleBinUuid) {
      uris.push(value);
    }

    match = valueRegex.exec(xml);
  }

  return uris;
}

function findStringContext(xml: string, valueIndex: number, valueLength: number): StringContext | null {
  const before: string = xml.substring(0, valueIndex);
  const stringOpen: number = before.lastIndexOf('<String>');
  if (stringOpen < 0) {
    return null;
  }
  if (before.lastIndexOf('</String>') > stringOpen) {
    return null;
  }

  const stringClose: number = xml.indexOf('</String>', valueIndex + valueLength);
  if (stringClose < 0) {
    return null;
  }
  const stringXml: string = xml.substring(stringOpen, stringClose + '</String>'.length);
  const key: string = extractTagText(stringXml, 'Key');

  const entryOpen: number = before.lastIndexOf('<Entry>');
  if (entryOpen < 0) {
    return null;
  }
  const entryBefore: string = xml.substring(0, entryOpen);
  const parentElement: string = nearestOpenElement(entryBefore, ['History', 'Group', 'Root']);

  let groupUuid: string = '';
  if (parentElement === 'Group' || parentElement === 'Root') {
    const openTag: string = parentElement === 'Root' ? '<Root>' : '<Group>';
    const groupOpen: number = entryBefore.lastIndexOf(openTag);
    if (groupOpen >= 0) {
      groupUuid = extractTagText(xml.substring(groupOpen, entryOpen), 'UUID');
    }
  }

  return { key: key, parentElement: parentElement, groupUuid: groupUuid };
}

function nearestOpenElement(before: string, candidates: string[]): string {
  let bestName: string = '';
  let bestPos: number = -1;
  for (let i: number = 0; i < candidates.length; i++) {
    const name: string = candidates[i];
    const openPos: number = before.lastIndexOf(`<${name}>`);
    const closePos: number = before.lastIndexOf(`</${name}>`);
    if (openPos > closePos && openPos > bestPos) {
      bestPos = openPos;
      bestName = name;
    }
  }
  return bestName;
}

function extractTagText(xml: string, tag: string): string {
  const open: string = `<${tag}>`;
  const close: string = `</${tag}>`;
  const start: number = xml.indexOf(open);
  if (start < 0) {
    return '';
  }
  const contentStart: number = start + open.length;
  const end: number = xml.indexOf(close, contentStart);
  if (end < 0) {
    return '';
  }
  return decodeXmlEntities(xml.substring(contentStart, end));
}

function decodeXmlEntities(text: string): string {
  return text
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

// ── Inner streams ──────────────────────────────────────────────────────────

async function createInnerStream(algorithm: InnerCipher, innerKey: Uint8Array): Promise<ProtectedStream> {
  if (algorithm === InnerCipher.Salsa20) {
    return new Salsa20Cipher(await sha256(innerKey), new Uint8Array(SALSA_IV));
  }
  if (algorithm === InnerCipher.ChaCha20) {
    const hash: Uint8Array = await sha512(innerKey);
    return new ChaCha20Cipher(hash.subarray(0, 32), hash.subarray(32, 44));
  }
  throw new Error(`Unsupported inner encryption algorithm ${algorithm}`);
}

class Salsa20Cipher implements ProtectedStream {
  private readonly state: number[] = new Array<number>(16);
  private readonly keystream: Uint8Array = new Uint8Array(BLOCK64);
  private keystreamPos: number = BLOCK64;

  constructor(key: Uint8Array, iv: Uint8Array) {
    if (key.length !== 32 || iv.length !== 8) {
      throw new Error('Salsa20 requires 32-byte key and 8-byte IV');
    }
    this.state[0] = SALSA_SIGMA[0];
    this.state[5] = SALSA_SIGMA[1];
    this.state[10] = SALSA_SIGMA[2];
    this.state[15] = SALSA_SIGMA[3];
    this.state[1] = readUint32LE(key, 0);
    this.state[2] = readUint32LE(key, 4);
    this.state[3] = readUint32LE(key, 8);
    this.state[4] = readUint32LE(key, 12);
    this.state[11] = readUint32LE(key, 16);
    this.state[12] = readUint32LE(key, 20);
    this.state[13] = readUint32LE(key, 24);
    this.state[14] = readUint32LE(key, 28);
    this.state[6] = readUint32LE(iv, 0);
    this.state[7] = readUint32LE(iv, 4);
    this.state[8] = 0;
    this.state[9] = 0;
  }

  process(input: Uint8Array): Uint8Array {
    const out: Uint8Array = new Uint8Array(input.length);
    for (let i: number = 0; i < input.length; i++) {
      if (this.keystreamPos >= BLOCK64) {
        this.generateBlock();
        this.keystreamPos = 0;
      }
      out[i] = input[i] ^ this.keystream[this.keystreamPos++];
    }
    return out;
  }

  private generateBlock(): void {
    const x: number[] = this.state.slice();
    for (let i: number = 0; i < DOUBLE_ROUNDS; i++) {
      salsaQR(x, 0, 4, 8, 12);
      salsaQR(x, 5, 9, 13, 1);
      salsaQR(x, 10, 14, 2, 6);
      salsaQR(x, 15, 3, 7, 11);
      salsaQR(x, 0, 1, 2, 3);
      salsaQR(x, 5, 6, 7, 4);
      salsaQR(x, 10, 11, 8, 9);
      salsaQR(x, 15, 12, 13, 14);
    }
    for (let i: number = 0; i < 16; i++) {
      writeUint32LE(this.keystream, i << 2, ((x[i] + this.state[i]) | 0) >>> 0);
    }
    this.state[8] = (this.state[8] + 1) >>> 0;
    if (this.state[8] === 0) {
      this.state[9] = (this.state[9] + 1) >>> 0;
    }
  }
}

function salsaQR(s: number[], a: number, b: number, c: number, d: number): void {
  s[b] ^= rotl((s[a] + s[d]) | 0, 7);
  s[c] ^= rotl((s[b] + s[a]) | 0, 9);
  s[d] ^= rotl((s[c] + s[b]) | 0, 13);
  s[a] ^= rotl((s[d] + s[c]) | 0, 18);
}

class ChaCha20Cipher implements ProtectedStream {
  private readonly key: Uint8Array;
  private readonly nonce: Uint8Array;
  private counter: number = 0;
  private readonly keystream: Uint8Array = new Uint8Array(BLOCK64);
  private keystreamPos: number = BLOCK64;

  constructor(key: Uint8Array, nonce: Uint8Array) {
    this.key = copyBytes(key);
    this.nonce = copyBytes(nonce);
  }

  process(input: Uint8Array): Uint8Array {
    const out: Uint8Array = new Uint8Array(input.length);
    for (let i: number = 0; i < input.length; i++) {
      if (this.keystreamPos >= BLOCK64) {
        chacha20Block(this.keystream, this.key, this.nonce, this.counter);
        this.counter = (this.counter + 1) >>> 0;
        this.keystreamPos = 0;
      }
      out[i] = input[i] ^ this.keystream[this.keystreamPos++];
    }
    return out;
  }
}

function chacha20IetfXor(key: Uint8Array, nonce12: Uint8Array, ic: number, input: Uint8Array): Uint8Array {
  const out: Uint8Array = new Uint8Array(input.length);
  const keystream: Uint8Array = new Uint8Array(BLOCK64);
  let counter: number = ic >>> 0;
  let offset: number = 0;
  while (offset < input.length) {
    chacha20Block(keystream, key, nonce12, counter);
    counter = (counter + 1) >>> 0;
    const n: number = Math.min(BLOCK64, input.length - offset);
    for (let i: number = 0; i < n; i++) {
      out[offset + i] = input[offset + i] ^ keystream[i];
    }
    offset += n;
  }
  return out;
}

function chacha20Block(out: Uint8Array, key: Uint8Array, nonce12: Uint8Array, counter: number): void {
  const state: number[] = new Array<number>(16);
  state[0] = CHACHA_CONST[0];
  state[1] = CHACHA_CONST[1];
  state[2] = CHACHA_CONST[2];
  state[3] = CHACHA_CONST[3];
  for (let i: number = 0; i < 8; i++) {
    state[4 + i] = readUint32LE(key, i << 2);
  }
  state[12] = counter >>> 0;
  state[13] = readUint32LE(nonce12, 0);
  state[14] = readUint32LE(nonce12, 4);
  state[15] = readUint32LE(nonce12, 8);

  const w: number[] = state.slice();
  for (let r: number = 0; r < DOUBLE_ROUNDS; r++) {
    quarterRound(w, 0, 4, 8, 12);
    quarterRound(w, 1, 5, 9, 13);
    quarterRound(w, 2, 6, 10, 14);
    quarterRound(w, 3, 7, 11, 15);
    quarterRound(w, 0, 5, 10, 15);
    quarterRound(w, 1, 6, 11, 12);
    quarterRound(w, 2, 7, 8, 13);
    quarterRound(w, 3, 4, 9, 14);
  }
  for (let i: number = 0; i < 16; i++) {
    writeUint32LE(out, i << 2, ((w[i] + state[i]) | 0) >>> 0);
  }
}

function quarterRound(s: number[], a: number, b: number, c: number, d: number): void {
  s[a] = (s[a] + s[b]) | 0;
  s[d] = rotl(s[d] ^ s[a], 16);
  s[c] = (s[c] + s[d]) | 0;
  s[b] = rotl(s[b] ^ s[c], 12);
  s[a] = (s[a] + s[b]) | 0;
  s[d] = rotl(s[d] ^ s[a], 8);
  s[c] = (s[c] + s[d]) | 0;
  s[b] = rotl(s[b] ^ s[c], 7);
}

function rotl(value: number, bits: number): number {
  return ((value << bits) | ((value >>> 0) >>> (32 - bits))) | 0;
}

// ── AES / hash ─────────────────────────────────────────────────────────────

async function aesCbcDecrypt(key: Uint8Array, iv: Uint8Array, ciphertext: Uint8Array): Promise<Uint8Array> {
  const gen: cryptoFramework.SymKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
  const symKey: cryptoFramework.SymKey = await gen.convertKey({ data: key });
  const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
  const ivParam: cryptoFramework.IvParamsSpec = { algName: 'IvParamsSpec', iv: { data: iv } };
  await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, ivParam);
  const decrypted: cryptoFramework.DataBlob | null = await cipher.doFinal({ data: ciphertext });
  if (!decrypted || !decrypted.data) {
    throw new Error('AES-CBC decrypt returned empty');
  }
  return decrypted.data;
}

async function aesEcbEncrypt(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
  const gen: cryptoFramework.SymKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
  const symKey: cryptoFramework.SymKey = await gen.convertKey({ data: key });
  const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|ECB|NoPadding');
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null);
  const encrypted: cryptoFramework.DataBlob | null = await cipher.doFinal({ data: data });
  if (!encrypted || !encrypted.data) {
    throw new Error('AES-ECB encrypt returned empty');
  }
  return encrypted.data;
}

async function sha256(data: Uint8Array): Promise<Uint8Array> {
  const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
  await md.update({ data: data });
  return (await md.digest()).data;
}

async function sha512(data: Uint8Array): Promise<Uint8Array> {
  const md: cryptoFramework.Md = cryptoFramework.createMd('SHA512');
  await md.update({ data: data });
  return (await md.digest()).data;
}

async function hmacSha256(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
  const mac: cryptoFramework.Mac = cryptoFramework.createMac('HMACSHA256');
  const gen: cryptoFramework.SymKeyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
  const symKey: cryptoFramework.SymKey = await gen.convertKey({ data: key });
  await mac.init(symKey);
  await mac.update({ data: data });
  return (await mac.doFinal()).data;
}

// ── GZip / raw DEFLATE ─────────────────────────────────────────────────────

const LENGTH_BASE: number[] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
  35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
];
const LENGTH_EXTRA: number[] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
  3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
];
const DIST_BASE: number[] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
  257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
];
const DIST_EXTRA: number[] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
  7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
];
const CODE_LENGTH_ORDER: number[] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
];

function gunzip(data: Uint8Array): Uint8Array {
  if (data.length < 10 || data[0] !== 0x1f || data[1] !== 0x8b) {
    throw new Error('Invalid GZip header');
  }
  if (data[2] !== 8) {
    throw new Error('Unsupported GZip compression method');
  }
  const flags: number = data[3];
  let offset: number = 10;

  if ((flags & 4) !== 0) {
    if (offset + 2 > data.length) {
      throw new Error('Truncated GZip extra field');
    }
    const xlen: number = data[offset] | (data[offset + 1] << 8);
    offset += 2 + xlen;
  }
  if ((flags & 8) !== 0) {
    while (offset < data.length && data[offset] !== 0) {
      offset++;
    }
    offset++;
  }
  if ((flags & 16) !== 0) {
    while (offset < data.length && data[offset] !== 0) {
      offset++;
    }
    offset++;
  }
  if ((flags & 2) !== 0) {
    offset += 2;
  }
  if (offset >= data.length - 8) {
    throw new Error('Truncated GZip stream');
  }

  return inflateRaw(data.subarray(offset, data.length - 8));
}

class BitReader {
  data: Uint8Array;
  pos: number = 0;
  bitBuf: number = 0;
  bitCount: number = 0;

  constructor(data: Uint8Array) {
    this.data = data;
  }

  ensureBits(n: number): void {
    while (this.bitCount < n) {
      if (this.pos >= this.data.length) {
        throw new Error('GZip/deflate: unexpected end of stream');
      }
      this.bitBuf |= this.data[this.pos++] << this.bitCount;
      this.bitCount += 8;
    }
  }

  peekBits(n: number): number {
    this.ensureBits(n);
    return this.bitBuf & ((1 << n) - 1);
  }

  consume(n: number): void {
    this.bitBuf >>>= n;
    this.bitCount -= n;
  }

  readBits(n: number): number {
    if (n === 0) {
      return 0;
    }
    this.ensureBits(n);
    const v: number = this.bitBuf & ((1 << n) - 1);
    this.consume(n);
    return v;
  }

  readByte(): number {
    this.alignToByte();
    if (this.pos >= this.data.length) {
      throw new Error('GZip/deflate: unexpected end of stream');
    }
    return this.data[this.pos++];
  }

  alignToByte(): void {
    this.bitBuf = 0;
    this.bitCount = 0;
  }
}

function inflateRaw(data: Uint8Array): Uint8Array {
  const bits: BitReader = new BitReader(data);
  const out: number[] = [];
  const fixedLit: HuffmanTable = buildFixedLitTable();
  const fixedDist: HuffmanTable = buildFixedDistTable();

  let last: boolean = false;
  while (!last) {
    last = bits.readBits(1) === 1;
    const type: number = bits.readBits(2);
    if (type === 0) {
      bits.alignToByte();
      const len: number = bits.readByte() | (bits.readByte() << 8);
      const nlen: number = bits.readByte() | (bits.readByte() << 8);
      if ((len ^ 0xffff) !== nlen) {
        throw new Error('GZip/deflate: invalid stored block length');
      }
      for (let i: number = 0; i < len; i++) {
        out.push(bits.readByte());
      }
    } else if (type === 1) {
      inflateBlock(bits, out, fixedLit, fixedDist);
    } else if (type === 2) {
      const tables: DynamicTables = buildDynamicTables(bits);
      inflateBlock(bits, out, tables.lit, tables.dist);
    } else {
      throw new Error('GZip/deflate: invalid block type');
    }
  }
  return new Uint8Array(out);
}

function inflateBlock(bits: BitReader, out: number[], lit: HuffmanTable, dist: HuffmanTable): void {
  while (true) {
    const sym: number = huffmanDecode(bits, lit);
    if (sym < 256) {
      out.push(sym);
    } else if (sym === 256) {
      break;
    } else {
      const lenIdx: number = sym - 257;
      if (lenIdx < 0 || lenIdx >= LENGTH_BASE.length) {
        throw new Error('GZip/deflate: invalid length symbol');
      }
      const length: number = LENGTH_BASE[lenIdx] + bits.readBits(LENGTH_EXTRA[lenIdx]);
      const distSym: number = huffmanDecode(bits, dist);
      if (distSym < 0 || distSym >= DIST_BASE.length) {
        throw new Error('GZip/deflate: invalid distance symbol');
      }
      const distance: number = DIST_BASE[distSym] + bits.readBits(DIST_EXTRA[distSym]);
      if (distance <= 0 || distance > out.length) {
        throw new Error('GZip/deflate: invalid backreference');
      }
      for (let i: number = 0; i < length; i++) {
        out.push(out[out.length - distance]);
      }
    }
  }
}

function huffmanDecode(bits: BitReader, table: HuffmanTable): number {
  if (table.maxBits === 0) {
    throw new Error('GZip/deflate: empty Huffman table');
  }
  const peek: number = bits.peekBits(table.maxBits);
  const len: number = table.bits[peek];
  if (len === 0) {
    throw new Error('GZip/deflate: invalid Huffman code');
  }
  const sym: number = table.symbols[peek];
  bits.consume(len);
  return sym;
}

function buildHuffmanTable(lengths: number[]): HuffmanTable {
  let maxBits: number = 0;
  for (let i: number = 0; i < lengths.length; i++) {
    if (lengths[i] > maxBits) {
      maxBits = lengths[i];
    }
  }
  if (maxBits === 0) {
    return { bits: [0], symbols: [0], maxBits: 0 };
  }

  const blCount: number[] = zeroArray(maxBits + 1);
  for (let i: number = 0; i < lengths.length; i++) {
    if (lengths[i] > 0) {
      blCount[lengths[i]]++;
    }
  }

  const nextCode: number[] = zeroArray(maxBits + 1);
  let code: number = 0;
  blCount[0] = 0;
  for (let bits: number = 1; bits <= maxBits; bits++) {
    code = (code + blCount[bits - 1]) << 1;
    nextCode[bits] = code;
  }

  const size: number = 1 << maxBits;
  const bitsArr: number[] = zeroArray(size);
  const symbols: number[] = zeroArray(size);

  for (let sym: number = 0; sym < lengths.length; sym++) {
    const len: number = lengths[sym];
    if (len === 0) {
      continue;
    }
    let c: number = nextCode[len]++;
    c = reverseBits(c, len);
    const step: number = 1 << len;
    for (let i: number = c; i < size; i += step) {
      bitsArr[i] = len;
      symbols[i] = sym;
    }
  }

  return { bits: bitsArr, symbols: symbols, maxBits: maxBits };
}

function reverseBits(code: number, len: number): number {
  let r: number = 0;
  let c: number = code;
  for (let i: number = 0; i < len; i++) {
    r = (r << 1) | (c & 1);
    c >>>= 1;
  }
  return r;
}

function buildFixedLitTable(): HuffmanTable {
  const lengths: number[] = new Array<number>(288);
  for (let i: number = 0; i <= 143; i++) {
    lengths[i] = 8;
  }
  for (let i: number = 144; i <= 255; i++) {
    lengths[i] = 9;
  }
  for (let i: number = 256; i <= 279; i++) {
    lengths[i] = 7;
  }
  for (let i: number = 280; i <= 287; i++) {
    lengths[i] = 8;
  }
  return buildHuffmanTable(lengths);
}

function buildFixedDistTable(): HuffmanTable {
  const lengths: number[] = zeroArray(32);
  for (let i: number = 0; i < 32; i++) {
    lengths[i] = 5;
  }
  return buildHuffmanTable(lengths);
}

function buildDynamicTables(bits: BitReader): DynamicTables {
  const hlit: number = bits.readBits(5) + 257;
  const hdist: number = bits.readBits(5) + 1;
  const hclen: number = bits.readBits(4) + 4;

  const codeLens: number[] = zeroArray(19);
  for (let i: number = 0; i < hclen; i++) {
    codeLens[CODE_LENGTH_ORDER[i]] = bits.readBits(3);
  }
  const codeTable: HuffmanTable = buildHuffmanTable(codeLens);

  const lengths: number[] = zeroArray(hlit + hdist);
  let i: number = 0;
  while (i < lengths.length) {
    const sym: number = huffmanDecode(bits, codeTable);
    if (sym < 16) {
      lengths[i++] = sym;
    } else if (sym === 16) {
      const rep: number = bits.readBits(2) + 3;
      const prev: number = i > 0 ? lengths[i - 1] : 0;
      for (let r: number = 0; r < rep; r++) {
        lengths[i++] = prev;
      }
    } else if (sym === 17) {
      const rep: number = bits.readBits(3) + 3;
      for (let r: number = 0; r < rep; r++) {
        lengths[i++] = 0;
      }
    } else if (sym === 18) {
      const rep: number = bits.readBits(7) + 11;
      for (let r: number = 0; r < rep; r++) {
        lengths[i++] = 0;
      }
    } else {
      throw new Error('GZip/deflate: invalid code length symbol');
    }
  }

  return {
    lit: buildHuffmanTable(lengths.slice(0, hlit)),
    dist: buildHuffmanTable(lengths.slice(hlit))
  };
}

// ── Helpers ────────────────────────────────────────────────────────────────

function zeroArray(length: number): number[] {
  const arr: number[] = new Array<number>(length);
  for (let i: number = 0; i < length; i++) {
    arr[i] = 0;
  }
  return arr;
}

function concatBytes(parts: Uint8Array[]): Uint8Array {
  let total: number = 0;
  for (let i: number = 0; i < parts.length; i++) {
    total += parts[i].length;
  }
  const out: Uint8Array = new Uint8Array(total);
  let offset: number = 0;
  for (let i: number = 0; i < parts.length; i++) {
    out.set(parts[i], offset);
    offset += parts[i].length;
  }
  return out;
}

function copyBytes(src: Uint8Array): Uint8Array {
  const out: Uint8Array = new Uint8Array(src.length);
  out.set(src);
  return out;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i: number = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

function bytesEqualArr(a: Uint8Array, b: number[]): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i: number = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let diff: number = 0;
  for (let i: number = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

function writeUInt64LE(value: number): Uint8Array {
  const out: Uint8Array = new Uint8Array(8);
  writeUint32LE(out, 0, value >>> 0);
  writeUint32LE(out, 4, Math.floor(value / 0x100000000) >>> 0);
  return out;
}

function readUint32LE(data: Uint8Array, offset: number): number {
  return (
    (data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24)) >>> 0
  );
}

function writeUint32LE(data: Uint8Array, offset: number, value: number): void {
  const v: number = value >>> 0;
  data[offset] = v & 0xff;
  data[offset + 1] = (v >>> 8) & 0xff;
  data[offset + 2] = (v >>> 16) & 0xff;
  data[offset + 3] = (v >>> 24) & 0xff;
}

function utf8Encode(text: string): Uint8Array {
  const bytes: number[] = [];
  for (let i: number = 0; i < text.length; i++) {
    let cp: number = text.charCodeAt(i);
    if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < text.length) {
      const next: number = text.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        cp = 0x10000 + ((cp - 0xD800) << 10) + (next - 0xDC00);
        i++;
      }
    }
    if (cp < 0x80) {
      bytes.push(cp);
    } else if (cp < 0x800) {
      bytes.push(0xC0 | (cp >> 6));
      bytes.push(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
      bytes.push(0xE0 | (cp >> 12));
      bytes.push(0x80 | ((cp >> 6) & 0x3F));
      bytes.push(0x80 | (cp & 0x3F));
    } else {
      bytes.push(0xF0 | (cp >> 18));
      bytes.push(0x80 | ((cp >> 12) & 0x3F));
      bytes.push(0x80 | ((cp >> 6) & 0x3F));
      bytes.push(0x80 | (cp & 0x3F));
    }
  }
  return new Uint8Array(bytes);
}

function utf8Decode(data: Uint8Array): string {
  let result: string = '';
  let i: number = 0;
  while (i < data.length) {
    const b1: number = data[i];
    if (b1 < 0x80) {
      result += String.fromCharCode(b1);
      i++;
    } else if ((b1 & 0xE0) === 0xC0 && i + 1 < data.length) {
      result += String.fromCharCode(((b1 & 0x1F) << 6) | (data[i + 1] & 0x3F));
      i += 2;
    } else if ((b1 & 0xF0) === 0xE0 && i + 2 < data.length) {
      result += String.fromCharCode(
        ((b1 & 0x0F) << 12) | ((data[i + 1] & 0x3F) << 6) | (data[i + 2] & 0x3F)
      );
      i += 3;
    } else if ((b1 & 0xF8) === 0xF0 && i + 3 < data.length) {
      const cp: number =
        ((b1 & 0x07) << 18) |
        ((data[i + 1] & 0x3F) << 12) |
        ((data[i + 2] & 0x3F) << 6) |
        (data[i + 3] & 0x3F);
      result += String.fromCharCode(0xD800 + ((cp - 0x10000) >> 10));
      result += String.fromCharCode(0xDC00 + ((cp - 0x10000) & 0x3FF));
      i += 4;
    } else {
      result += String.fromCharCode(b1);
      i++;
    }
  }
  return result;
}

function base64Decode(text: string): Uint8Array {
  const helper: util.Base64Helper = new util.Base64Helper();
  return helper.decodeSync(text.trim());
}
