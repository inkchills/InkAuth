/**
 * Libsodium-style XChaCha20-Poly1305 secretstream pull (Ente Auth).
 * Port of Stratum.Core Converter.Crypto (HChaCha20 + XChaCha20Poly1305Stream).
 *
 * Ciphertext layout: [1-byte tag][message...][16-byte Poly1305 MAC]
 */

const KEY_SIZE: number = 32;
const NONCE_SIZE: number = 12;
const HEADER_SIZE: number = 24;
const BLOCK_SIZE: number = 64;
const MAC_SIZE: number = 16;
const ABYTES: number = 1 + MAC_SIZE;
const CHACHA_ROUNDS: number = 10;
const TAG_REKEY: number = 2;

const CHACHA_CONSTANT: number[] = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574];
const HCHACHA_OUT_INDEX: number[] = [0, 1, 2, 3, 12, 13, 14, 15];

/**
 * Decrypt one secretstream message (empty associated data), matching Ente Auth / Android.
 * @param key 32-byte key
 * @param headerNonce24 24-byte header (HChaCha20 input || inonce)
 * @param ciphertext [tag][message][mac]
 */
export function xchacha20Poly1305Pull(
  key: Uint8Array,
  headerNonce24: Uint8Array,
  ciphertext: Uint8Array
): Uint8Array {
  if (key.length !== KEY_SIZE) {
    throw new Error('xchacha20Poly1305Pull: key must be 32 bytes');
  }
  if (headerNonce24.length !== HEADER_SIZE) {
    throw new Error('xchacha20Poly1305Pull: header must be 24 bytes');
  }
  if (ciphertext.length < ABYTES) {
    throw new Error('xchacha20Poly1305Pull: ciphertext too short');
  }

  const subKey: Uint8Array = hchacha20(key, headerNonce24.subarray(0, 16));

  // IETF ChaCha20 nonce: [u32le counter=1][header[16..24]]
  const nonce: Uint8Array = new Uint8Array(NONCE_SIZE);
  writeUint32LE(nonce, 0, 1);
  nonce.set(headerNonce24.subarray(16, 24), 4);

  const messageLength: number = ciphertext.length - ABYTES;

  // IC=0 → Poly1305 one-time key
  const polyKeyBlock: Uint8Array = chacha20IetfBlock(subKey, nonce, 0);
  const poly: Poly1305 = new Poly1305(polyKeyBlock.subarray(0, KEY_SIZE));

  // IC=1: full 64-byte encrypted tag block (only byte 0 stored on wire).
  // After XOR: [ct^ks0, ks1..ks63]; restore byte0 → MAC over [ct_tag, ks1..ks63].
  const tagBlock: Uint8Array = new Uint8Array(BLOCK_SIZE);
  tagBlock[0] = ciphertext[0];
  xorInPlace(tagBlock, chacha20IetfBlock(subKey, nonce, 1));
  const tag: number = tagBlock[0];
  tagBlock[0] = ciphertext[0];
  poly.update(tagBlock, 0, BLOCK_SIZE);

  const cipherBody: Uint8Array = ciphertext.subarray(1, 1 + messageLength);
  poly.update(cipherBody, 0, messageLength);

  // libsodium pad formula (kept as-is for interoperability)
  const padLength: number = (0x10 - BLOCK_SIZE + messageLength) & 0xf;
  if (padLength > 0) {
    poly.update(new Uint8Array(padLength), 0, padLength);
  }

  const slen: Uint8Array = new Uint8Array(8);
  poly.update(slen, 0, 8); // adlen = 0
  writeUint64LE(slen, 0, BLOCK_SIZE + messageLength);
  poly.update(slen, 0, 8);

  const computedMac: Uint8Array = poly.finish();
  const givenMac: Uint8Array = ciphertext.subarray(1 + messageLength);
  if (!constantTimeEqual(computedMac, givenMac)) {
    throw new Error('xchacha20Poly1305Pull: MAC does not match');
  }

  if ((tag & TAG_REKEY) !== 0) {
    throw new Error('xchacha20Poly1305Pull: rekeying not supported');
  }

  return chacha20IetfXor(subKey, nonce, 2, cipherBody);
}

/** HChaCha20 subkey derivation. */
function hchacha20(key: Uint8Array, nonce16: Uint8Array): Uint8Array {
  const state: number[] = new Array<number>(16);
  state[0] = CHACHA_CONSTANT[0];
  state[1] = CHACHA_CONSTANT[1];
  state[2] = CHACHA_CONSTANT[2];
  state[3] = CHACHA_CONSTANT[3];
  for (let i = 0; i < 8; i++) {
    state[4 + i] = readUint32LE(key, i << 2);
  }
  for (let i = 0; i < 4; i++) {
    state[12 + i] = readUint32LE(nonce16, i << 2);
  }

  for (let i = 0; i < CHACHA_ROUNDS; i++) {
    quarterRound(state, 0, 4, 8, 12);
    quarterRound(state, 1, 5, 9, 13);
    quarterRound(state, 2, 6, 10, 14);
    quarterRound(state, 3, 7, 11, 15);
    quarterRound(state, 0, 5, 10, 15);
    quarterRound(state, 1, 6, 11, 12);
    quarterRound(state, 2, 7, 8, 13);
    quarterRound(state, 3, 4, 9, 14);
  }

  const out: Uint8Array = new Uint8Array(KEY_SIZE);
  for (let i = 0; i < 8; i++) {
    writeUint32LE(out, i << 2, state[HCHACHA_OUT_INDEX[i]] >>> 0);
  }
  return out;
}

function chacha20IetfBlock(key: Uint8Array, nonce12: Uint8Array, counter: number): Uint8Array {
  const block: Uint8Array = new Uint8Array(BLOCK_SIZE);
  chacha20IetfXorIc(block, new Uint8Array(BLOCK_SIZE), key, nonce12, counter);
  return block;
}

function chacha20IetfXor(
  key: Uint8Array,
  nonce12: Uint8Array,
  ic: number,
  input: Uint8Array
): Uint8Array {
  const out: Uint8Array = new Uint8Array(input.length);
  chacha20IetfXorIc(out, input, key, nonce12, ic);
  return out;
}

function chacha20IetfXorIc(
  out: Uint8Array,
  input: Uint8Array,
  key: Uint8Array,
  nonce12: Uint8Array,
  ic: number
): void {
  const state: number[] = new Array<number>(16);
  state[0] = CHACHA_CONSTANT[0];
  state[1] = CHACHA_CONSTANT[1];
  state[2] = CHACHA_CONSTANT[2];
  state[3] = CHACHA_CONSTANT[3];
  for (let i = 0; i < 8; i++) {
    state[4 + i] = readUint32LE(key, i << 2);
  }
  state[12] = ic >>> 0;
  state[13] = readUint32LE(nonce12, 0);
  state[14] = readUint32LE(nonce12, 4);
  state[15] = readUint32LE(nonce12, 8);

  const working: number[] = new Array<number>(16);
  const keystream: Uint8Array = new Uint8Array(BLOCK_SIZE);
  let offset: number = 0;

  while (offset < input.length) {
    for (let i = 0; i < 16; i++) {
      working[i] = state[i];
    }
    for (let i = 0; i < CHACHA_ROUNDS; i++) {
      quarterRound(working, 0, 4, 8, 12);
      quarterRound(working, 1, 5, 9, 13);
      quarterRound(working, 2, 6, 10, 14);
      quarterRound(working, 3, 7, 11, 15);
      quarterRound(working, 0, 5, 10, 15);
      quarterRound(working, 1, 6, 11, 12);
      quarterRound(working, 2, 7, 8, 13);
      quarterRound(working, 3, 4, 9, 14);
    }
    for (let i = 0; i < 16; i++) {
      writeUint32LE(keystream, i << 2, ((working[i] + state[i]) | 0) >>> 0);
    }

    const n: number = Math.min(BLOCK_SIZE, input.length - offset);
    for (let i = 0; i < n; i++) {
      out[offset + i] = input[offset + i] ^ keystream[i];
    }
    offset += n;
    state[12] = (state[12] + 1) >>> 0;
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

function xorInPlace(dst: Uint8Array, keystream: Uint8Array): void {
  const n: number = Math.min(dst.length, keystream.length);
  for (let i = 0; i < n; i++) {
    dst[i] = dst[i] ^ keystream[i];
  }
}

/**
 * Poly1305 (RFC 7539), TweetNaCl-style 26-bit limbs.
 * Clamped r keeps intermediates within float64 exact-integer range per block.
 */
class Poly1305 {
  private readonly r0: number;
  private readonly r1: number;
  private readonly r2: number;
  private readonly r3: number;
  private readonly r4: number;
  private readonly s1: number;
  private readonly s2: number;
  private readonly s3: number;
  private readonly s4: number;
  private readonly pad0: number;
  private readonly pad1: number;
  private readonly pad2: number;
  private readonly pad3: number;
  private h0: number = 0;
  private h1: number = 0;
  private h2: number = 0;
  private h3: number = 0;
  private h4: number = 0;
  private readonly buffer: Uint8Array = new Uint8Array(16);
  private bufferLen: number = 0;
  private finished: boolean = false;

  constructor(key: Uint8Array) {
    if (key.length < KEY_SIZE) {
      throw new Error('Poly1305: key must be 32 bytes');
    }
    const t0: number = readUint32LE(key, 0);
    const t1: number = readUint32LE(key, 4);
    const t2: number = readUint32LE(key, 8);
    const t3: number = readUint32LE(key, 12);

    this.r0 = t0 & 0x3ffffff;
    this.r1 = ((t0 >>> 26) | (t1 << 6)) & 0x3ffff03;
    this.r2 = ((t1 >>> 20) | (t2 << 12)) & 0x3ffc0ff;
    this.r3 = ((t2 >>> 14) | (t3 << 18)) & 0x3f03fff;
    this.r4 = (t3 >>> 8) & 0x00fffff;

    this.s1 = this.r1 * 5;
    this.s2 = this.r2 * 5;
    this.s3 = this.r3 * 5;
    this.s4 = this.r4 * 5;

    this.pad0 = readUint32LE(key, 16);
    this.pad1 = readUint32LE(key, 20);
    this.pad2 = readUint32LE(key, 24);
    this.pad3 = readUint32LE(key, 28);
  }

  update(data: Uint8Array, offset: number, length: number): void {
    if (this.finished) {
      throw new Error('Poly1305: already finished');
    }
    let off: number = offset;
    let rem: number = length;

    if (this.bufferLen > 0) {
      const want: number = 16 - this.bufferLen;
      const n: number = rem < want ? rem : want;
      for (let i = 0; i < n; i++) {
        this.buffer[this.bufferLen + i] = data[off + i];
      }
      this.bufferLen += n;
      off += n;
      rem -= n;
      if (this.bufferLen === 16) {
        this.blocks(this.buffer, 0, 16, false);
        this.bufferLen = 0;
      }
    }

    if (rem >= 16) {
      const aligned: number = rem & ~15;
      this.blocks(data, off, aligned, false);
      off += aligned;
      rem -= aligned;
    }

    if (rem > 0) {
      for (let i = 0; i < rem; i++) {
        this.buffer[i] = data[off + i];
      }
      this.bufferLen = rem;
    }
  }

  finish(): Uint8Array {
    if (this.finished) {
      throw new Error('Poly1305: already finished');
    }
    this.finished = true;

    if (this.bufferLen > 0) {
      const block: Uint8Array = new Uint8Array(16);
      for (let i = 0; i < this.bufferLen; i++) {
        block[i] = this.buffer[i];
      }
      block[this.bufferLen] = 1;
      this.blocks(block, 0, 16, true);
    }

    let h0: number = this.h0;
    let h1: number = this.h1;
    let h2: number = this.h2;
    let h3: number = this.h3;
    let h4: number = this.h4;

    let c: number = h1 >>> 26;
    h1 &= 0x3ffffff;
    h2 += c;
    c = h2 >>> 26;
    h2 &= 0x3ffffff;
    h3 += c;
    c = h3 >>> 26;
    h3 &= 0x3ffffff;
    h4 += c;
    c = h4 >>> 26;
    h4 &= 0x3ffffff;
    h0 += c * 5;
    c = h0 >>> 26;
    h0 &= 0x3ffffff;
    h1 += c;

    let g0: number = (h0 + 5) | 0;
    c = g0 >>> 26;
    g0 &= 0x3ffffff;
    let g1: number = (h1 + c) | 0;
    c = g1 >>> 26;
    g1 &= 0x3ffffff;
    let g2: number = (h2 + c) | 0;
    c = g2 >>> 26;
    g2 &= 0x3ffffff;
    let g3: number = (h3 + c) | 0;
    c = g3 >>> 26;
    g3 &= 0x3ffffff;
    let g4: number = (h4 + c - (1 << 26)) | 0;

    const mask: number = (g4 >>> 31) - 1;
    const nmask: number = ~mask;
    h0 = (h0 & nmask) | (g0 & mask);
    h1 = (h1 & nmask) | (g1 & mask);
    h2 = (h2 & nmask) | (g2 & mask);
    h3 = (h3 & nmask) | (g3 & mask);
    h4 = (h4 & nmask) | (g4 & mask);

    const f0: number = ((h0 | (h1 << 26)) >>> 0);
    const f1: number = (((h1 >>> 6) | (h2 << 20)) >>> 0);
    const f2: number = (((h2 >>> 12) | (h3 << 14)) >>> 0);
    const f3: number = (((h3 >>> 18) | (h4 << 8)) >>> 0);

    let t: number = f0 + this.pad0;
    const m0: number = t >>> 0;
    t = Math.floor(t / 0x100000000) + f1 + this.pad1;
    const m1: number = t >>> 0;
    t = Math.floor(t / 0x100000000) + f2 + this.pad2;
    const m2: number = t >>> 0;
    t = Math.floor(t / 0x100000000) + f3 + this.pad3;
    const m3: number = t >>> 0;

    const mac: Uint8Array = new Uint8Array(MAC_SIZE);
    writeUint32LE(mac, 0, m0);
    writeUint32LE(mac, 4, m1);
    writeUint32LE(mac, 8, m2);
    writeUint32LE(mac, 12, m3);
    return mac;
  }

  private blocks(data: Uint8Array, offset: number, length: number, skipPad: boolean): void {
    const hibit: number = skipPad ? 0 : (1 << 24);
    let h0: number = this.h0;
    let h1: number = this.h1;
    let h2: number = this.h2;
    let h3: number = this.h3;
    let h4: number = this.h4;
    const r0: number = this.r0;
    const r1: number = this.r1;
    const r2: number = this.r2;
    const r3: number = this.r3;
    const r4: number = this.r4;
    const s1: number = this.s1;
    const s2: number = this.s2;
    const s3: number = this.s3;
    const s4: number = this.s4;

    let off: number = offset;
    const end: number = offset + length;
    while (off < end) {
      const t0: number = readUint32LE(data, off);
      const t1: number = readUint32LE(data, off + 4);
      const t2: number = readUint32LE(data, off + 8);
      const t3: number = readUint32LE(data, off + 12);

      h0 += t0 & 0x3ffffff;
      h1 += ((t0 >>> 26) | (t1 << 6)) & 0x3ffffff;
      h2 += ((t1 >>> 20) | (t2 << 12)) & 0x3ffffff;
      h3 += ((t2 >>> 14) | (t3 << 18)) & 0x3ffffff;
      h4 += (t3 >>> 8) | hibit;

      const d0: number = h0 * r0 + h1 * s4 + h2 * s3 + h3 * s2 + h4 * s1;
      const d1: number = h0 * r1 + h1 * r0 + h2 * s4 + h3 * s3 + h4 * s2;
      const d2: number = h0 * r2 + h1 * r1 + h2 * r0 + h3 * s4 + h4 * s3;
      const d3: number = h0 * r3 + h1 * r2 + h2 * r1 + h3 * r0 + h4 * s4;
      const d4: number = h0 * r4 + h1 * r3 + h2 * r2 + h3 * r1 + h4 * r0;

      let c: number = (d0 / 0x4000000) | 0;
      h0 = d0 & 0x3ffffff;
      let d1c: number = d1 + c;
      c = (d1c / 0x4000000) | 0;
      h1 = d1c & 0x3ffffff;
      let d2c: number = d2 + c;
      c = (d2c / 0x4000000) | 0;
      h2 = d2c & 0x3ffffff;
      let d3c: number = d3 + c;
      c = (d3c / 0x4000000) | 0;
      h3 = d3c & 0x3ffffff;
      let d4c: number = d4 + c;
      c = (d4c / 0x4000000) | 0;
      h4 = d4c & 0x3ffffff;
      h0 += c * 5;
      c = (h0 / 0x4000000) | 0;
      h0 &= 0x3ffffff;
      h1 += c;

      off += 16;
    }

    this.h0 = h0;
    this.h1 = h1;
    this.h2 = h2;
    this.h3 = h3;
    this.h4 = h4;
  }
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let diff: number = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
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

function writeUint64LE(data: Uint8Array, offset: number, value: number): void {
  const lo: number = value >>> 0;
  const hi: number = Math.floor(value / 0x100000000) >>> 0;
  writeUint32LE(data, offset, lo);
  writeUint32LE(data, offset + 4, hi);
}
