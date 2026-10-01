/**
 * Classic SCrypt (RFC 7914) for Aegis-style key derivation.
 * PBKDF2-HMAC-SHA256 via cryptoFramework; salsa20/8 ROMix in pure ArkTS.
 * Typical Aegis params: N=32768, r=8, p=1, dkLen=32
 */

import { cryptoFramework } from '@kit.CryptoArchitectureKit';

const SALSA_ROUNDS: number = 4; // salsa20/8 => 4 double-rounds
const BLOCK_WORDS: number = 16; // 64 bytes

/**
 * Decode a hex string into bytes. Accepts optional whitespace; even length required.
 */
export function hexToBytes(hex: string): Uint8Array {
  const cleaned: string = hex.replace(/\s+/g, '');
  if ((cleaned.length & 1) !== 0) {
    throw new Error('hexToBytes: hex string must have even length');
  }
  const out: Uint8Array = new Uint8Array(cleaned.length >> 1);
  for (let i = 0; i < out.length; i++) {
    const byteHex: string = cleaned.substring(i << 1, (i << 1) + 2);
    const value: number = Number.parseInt(byteHex, 16);
    if (Number.isNaN(value)) {
      throw new Error('hexToBytes: invalid hex');
    }
    out[i] = value;
  }
  return out;
}

/**
 * RFC 7914 scrypt.
 * @param password password bytes
 * @param salt salt bytes
 * @param N CPU/memory cost (power of two)
 * @param r block size parameter
 * @param p parallelization
 * @param dkLen derived key length in bytes
 */
export async function scrypt(
  password: Uint8Array,
  salt: Uint8Array,
  N: number,
  r: number,
  p: number,
  dkLen: number
): Promise<Uint8Array> {
  if (N < 2 || (N & (N - 1)) !== 0) {
    throw new Error('scrypt: N must be a power of 2 >= 2');
  }
  if (r < 1 || p < 1 || dkLen < 1) {
    throw new Error('scrypt: invalid r, p, or dkLen');
  }
  // r * p < 2^30 is the RFC bound; keep a practical check
  if (r * p >= 0x40000000) {
    throw new Error('scrypt: r * p too large');
  }

  const blockBytes: number = 128 * r;
  const B: Uint8Array = await pbkdf2Sha256(password, salt, 1, p * blockBytes);

  // X (32*r) + Y (32*r) + salsa scratch (16)
  const XY: Int32Array = new Int32Array(64 * r + BLOCK_WORDS);
  const V: Int32Array = new Int32Array(32 * r * N);

  for (let i = 0; i < p; i++) {
    const offset: number = i * blockBytes;
    romix(B, offset, r, N, V, XY);
  }

  return await pbkdf2Sha256(password, B, 1, dkLen);
}

async function pbkdf2Sha256(
  password: Uint8Array,
  salt: Uint8Array,
  iterations: number,
  keySize: number
): Promise<Uint8Array> {
  const kdf: cryptoFramework.Kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
  // HarmonyOS accepts string | Uint8Array for password
  const passwordParam: string | Uint8Array = password;
  const spec: cryptoFramework.PBKDF2Spec = {
    algName: 'PBKDF2',
    password: passwordParam,
    salt: salt,
    iterations: iterations,
    keySize: keySize
  };
  const derived: cryptoFramework.DataBlob = await kdf.generateSecret(spec);
  return derived.data;
}

/**
 * ROMix on one 128*r-byte block stored at `B[offset..]`.
 * V holds N blocks of 32*r little-endian words.
 */
function romix(
  B: Uint8Array,
  offset: number,
  r: number,
  N: number,
  V: Int32Array,
  XY: Int32Array
): void {
  const wordsPerBlock: number = 32 * r;
  const X: Int32Array = XY.subarray(0, wordsPerBlock);
  const Y: Int32Array = XY.subarray(wordsPerBlock, wordsPerBlock * 2);
  const scratch: Int32Array = XY.subarray(wordsPerBlock * 2, wordsPerBlock * 2 + BLOCK_WORDS);

  bytesToWordsLE(B, offset, X, 0, wordsPerBlock);

  for (let i = 0; i < N; i++) {
    V.set(X, i * wordsPerBlock);
    blockMix(X, Y, r, scratch);
    X.set(Y);
  }

  for (let i = 0; i < N; i++) {
    const j: number = integerify(X, r) & (N - 1);
    const vOff: number = j * wordsPerBlock;
    for (let k = 0; k < wordsPerBlock; k++) {
      X[k] = (X[k] ^ V[vOff + k]) | 0;
    }
    blockMix(X, Y, r, scratch);
    X.set(Y);
  }

  wordsToBytesLE(X, 0, B, offset, wordsPerBlock);
}

/** Integerify: last 64-byte block as little-endian integer; only low 32 bits needed for N < 2^32. */
function integerify(X: Int32Array, r: number): number {
  return X[wordsIndex(2 * r - 1, 0)] >>> 0;
}

function wordsIndex(blockIndex: number, wordInBlock: number): number {
  return blockIndex * BLOCK_WORDS + wordInBlock;
}

/**
 * BlockMix_salsa20/8 (RFC 7914).
 * Input/output are 32*r little-endian words. `scratch` must be 16 words.
 */
function blockMix(B: Int32Array, Y: Int32Array, r: number, scratch: Int32Array): void {
  // X = B_{2r-1}
  copy16(B, wordsIndex(2 * r - 1, 0), scratch, 0);

  for (let i = 0; i < 2 * r; i++) {
    const bOff: number = wordsIndex(i, 0);
    for (let j = 0; j < BLOCK_WORDS; j++) {
      scratch[j] = (scratch[j] ^ B[bOff + j]) | 0;
    }
    salsa208Core(scratch);

    // Even blocks → first half of Y, odd → second half
    const yBlock: number = (i >>> 1) + (i & 1) * r;
    copy16(scratch, 0, Y, wordsIndex(yBlock, 0));
  }
}

/** salsa20/8 core in-place on 16 words (RFC 7914 / Bernstein). */
function salsa208Core(B: Int32Array): void {
  let x0: number = B[0] | 0;
  let x1: number = B[1] | 0;
  let x2: number = B[2] | 0;
  let x3: number = B[3] | 0;
  let x4: number = B[4] | 0;
  let x5: number = B[5] | 0;
  let x6: number = B[6] | 0;
  let x7: number = B[7] | 0;
  let x8: number = B[8] | 0;
  let x9: number = B[9] | 0;
  let x10: number = B[10] | 0;
  let x11: number = B[11] | 0;
  let x12: number = B[12] | 0;
  let x13: number = B[13] | 0;
  let x14: number = B[14] | 0;
  let x15: number = B[15] | 0;

  for (let i = 0; i < SALSA_ROUNDS; i++) {
    // column rounds
    x4 ^= rotl((x0 + x12) | 0, 7);
    x8 ^= rotl((x4 + x0) | 0, 9);
    x12 ^= rotl((x8 + x4) | 0, 13);
    x0 ^= rotl((x12 + x8) | 0, 18);

    x9 ^= rotl((x5 + x1) | 0, 7);
    x13 ^= rotl((x9 + x5) | 0, 9);
    x1 ^= rotl((x13 + x9) | 0, 13);
    x5 ^= rotl((x1 + x13) | 0, 18);

    x14 ^= rotl((x10 + x6) | 0, 7);
    x2 ^= rotl((x14 + x10) | 0, 9);
    x6 ^= rotl((x2 + x14) | 0, 13);
    x10 ^= rotl((x6 + x2) | 0, 18);

    x3 ^= rotl((x15 + x11) | 0, 7);
    x7 ^= rotl((x3 + x15) | 0, 9);
    x11 ^= rotl((x7 + x3) | 0, 13);
    x15 ^= rotl((x11 + x7) | 0, 18);

    // row rounds
    x1 ^= rotl((x0 + x3) | 0, 7);
    x2 ^= rotl((x1 + x0) | 0, 9);
    x3 ^= rotl((x2 + x1) | 0, 13);
    x0 ^= rotl((x3 + x2) | 0, 18);

    x6 ^= rotl((x5 + x4) | 0, 7);
    x7 ^= rotl((x6 + x5) | 0, 9);
    x4 ^= rotl((x7 + x6) | 0, 13);
    x5 ^= rotl((x4 + x7) | 0, 18);

    x11 ^= rotl((x10 + x9) | 0, 7);
    x8 ^= rotl((x11 + x10) | 0, 9);
    x9 ^= rotl((x8 + x11) | 0, 13);
    x10 ^= rotl((x9 + x8) | 0, 18);

    x12 ^= rotl((x15 + x14) | 0, 7);
    x13 ^= rotl((x12 + x15) | 0, 9);
    x14 ^= rotl((x13 + x12) | 0, 13);
    x15 ^= rotl((x14 + x13) | 0, 18);
  }

  B[0] = (B[0] + x0) | 0;
  B[1] = (B[1] + x1) | 0;
  B[2] = (B[2] + x2) | 0;
  B[3] = (B[3] + x3) | 0;
  B[4] = (B[4] + x4) | 0;
  B[5] = (B[5] + x5) | 0;
  B[6] = (B[6] + x6) | 0;
  B[7] = (B[7] + x7) | 0;
  B[8] = (B[8] + x8) | 0;
  B[9] = (B[9] + x9) | 0;
  B[10] = (B[10] + x10) | 0;
  B[11] = (B[11] + x11) | 0;
  B[12] = (B[12] + x12) | 0;
  B[13] = (B[13] + x13) | 0;
  B[14] = (B[14] + x14) | 0;
  B[15] = (B[15] + x15) | 0;
}

function rotl(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) | 0;
}

function copy16(src: Int32Array, srcOff: number, dst: Int32Array, dstOff: number): void {
  for (let i = 0; i < BLOCK_WORDS; i++) {
    dst[dstOff + i] = src[srcOff + i];
  }
}

function bytesToWordsLE(
  bytes: Uint8Array,
  byteOffset: number,
  words: Int32Array,
  wordOffset: number,
  wordCount: number
): void {
  for (let i = 0; i < wordCount; i++) {
    const o: number = byteOffset + (i << 2);
    words[wordOffset + i] =
      (bytes[o] |
        (bytes[o + 1] << 8) |
        (bytes[o + 2] << 16) |
        (bytes[o + 3] << 24)) | 0;
  }
}

function wordsToBytesLE(
  words: Int32Array,
  wordOffset: number,
  bytes: Uint8Array,
  byteOffset: number,
  wordCount: number
): void {
  for (let i = 0; i < wordCount; i++) {
    const w: number = words[wordOffset + i];
    const o: number = byteOffset + (i << 2);
    bytes[o] = w & 0xff;
    bytes[o + 1] = (w >>> 8) & 0xff;
    bytes[o + 2] = (w >>> 16) & 0xff;
    bytes[o + 3] = (w >>> 24) & 0xff;
  }
}
