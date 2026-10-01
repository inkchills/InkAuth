/**
 * Compact QR Code → SVG generator for HarmonyOS ArkTS.
 * Byte mode, ECC level M, versions 1–15 (~400 byte otpauth URIs).
 */

/** Total codewords per version (1–15). */
const TOTAL_CW: number[] = [
  0,
  26, 44, 70, 100, 134, 172, 196, 242, 292, 346,
  404, 466, 532, 581, 655
];

/** ECC codewords per block for level M (1–15). */
const ECC_CW: number[] = [
  0,
  10, 16, 26, 18, 24, 16, 18, 22, 22, 26,
  30, 22, 22, 24, 24
];

/** Number of ECC blocks for level M (1–15). */
const ECC_BLOCKS: number[] = [
  0,
  1, 1, 1, 2, 2, 4, 4, 4, 5, 5,
  5, 8, 9, 9, 10
];

/** Alignment pattern center positions for versions 1–15. */
const ALIGN_POS: number[][] = [
  [],
  [],
  [6, 18],
  [6, 22],
  [6, 26],
  [6, 30],
  [6, 34],
  [6, 22, 38],
  [6, 24, 42],
  [6, 26, 46],
  [6, 28, 50],
  [6, 30, 54],
  [6, 32, 58],
  [6, 34, 62],
  [6, 26, 46, 66],
  [6, 26, 48, 70]
];

/** Format info bits for ECC-M + mask 0–7 (15-bit, LSB = bit 0). */
const FORMAT_BITS: number[] = [
  0x5412, 0x5125, 0x5E7C, 0x5B4B, 0x45F9, 0x40CE, 0x4F97, 0x4AA0
];

/** Version info bits for versions 7–15 (18-bit, LSB = bit 0). */
const VERSION_BITS: number[] = [
  0, 0, 0, 0, 0, 0, 0,
  0x07C94, 0x085BC, 0x09A99, 0x0A4D3, 0x0BBF6, 0x0C762, 0x0D847, 0x0E60D, 0x0F855
];

// ---- GF(256) / Reed-Solomon ----

const EXP: number[] = new Array<number>(512);
const LOG: number[] = new Array<number>(256);

function initGf(): void {
  let x: number = 1;
  for (let i: number = 0; i < 255; i++) {
    EXP[i] = x;
    LOG[x] = i;
    x <<= 1;
    if (x >= 256) {
      x ^= 0x11D;
    }
  }
  for (let i: number = 255; i < 512; i++) {
    EXP[i] = EXP[i - 255];
  }
  LOG[0] = 0;
}

initGf();

function gfMul(a: number, b: number): number {
  if (a === 0 || b === 0) {
    return 0;
  }
  return EXP[LOG[a] + LOG[b]];
}

/** Generator polynomial coefficients, highest degree first (length ecLen+1). */
function rsGenerator(ecLen: number): number[] {
  let gen: number[] = [1];
  for (let i: number = 0; i < ecLen; i++) {
    const next: number[] = [];
    for (let k: number = 0; k < gen.length + 1; k++) {
      next.push(0);
    }
    for (let j: number = 0; j < gen.length; j++) {
      next[j] ^= gen[j];
      next[j + 1] ^= gfMul(gen[j], EXP[i]);
    }
    gen = next;
  }
  return gen;
}

function rsEncode(data: number[], ecLen: number): number[] {
  const gen: number[] = rsGenerator(ecLen);
  const msg: number[] = [];
  for (let i: number = 0; i < data.length; i++) {
    msg.push(data[i]);
  }
  for (let i: number = 0; i < ecLen; i++) {
    msg.push(0);
  }
  for (let i: number = 0; i < data.length; i++) {
    const coef: number = msg[i];
    if (coef !== 0) {
      for (let j: number = 0; j < gen.length; j++) {
        msg[i + j] ^= gfMul(gen[j], coef);
      }
    }
  }
  return msg.slice(data.length);
}

// ---- Bit buffer ----

class BitBuffer {
  bits: number[] = [];

  append(val: number, len: number): void {
    for (let i: number = len - 1; i >= 0; i--) {
      this.bits.push((val >>> i) & 1);
    }
  }

  toBytes(): number[] {
    const out: number[] = [];
    for (let i: number = 0; i < this.bits.length; i += 8) {
      let b: number = 0;
      for (let j: number = 0; j < 8; j++) {
        b = (b << 1) | (i + j < this.bits.length ? this.bits[i + j] : 0);
      }
      out.push(b);
    }
    return out;
  }

  get length(): number {
    return this.bits.length;
  }
}

// ---- UTF-8 ----

function toUtf8Bytes(text: string): number[] {
  const bytes: number[] = [];
  for (let i: number = 0; i < text.length; i++) {
    let c: number = text.charCodeAt(i);
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
      const c2: number = text.charCodeAt(i + 1);
      if (c2 >= 0xDC00 && c2 <= 0xDFFF) {
        c = 0x10000 + ((c & 0x3FF) << 10) + (c2 & 0x3FF);
        i++;
      }
    }
    if (c < 0x80) {
      bytes.push(c);
    } else if (c < 0x800) {
      bytes.push(0xC0 | (c >> 6));
      bytes.push(0x80 | (c & 0x3F));
    } else if (c < 0x10000) {
      bytes.push(0xE0 | (c >> 12));
      bytes.push(0x80 | ((c >> 6) & 0x3F));
      bytes.push(0x80 | (c & 0x3F));
    } else {
      bytes.push(0xF0 | (c >> 18));
      bytes.push(0x80 | ((c >> 12) & 0x3F));
      bytes.push(0x80 | ((c >> 6) & 0x3F));
      bytes.push(0x80 | (c & 0x3F));
    }
  }
  return bytes;
}

// ---- Capacity / version ----

function dataCapacity(version: number): number {
  return TOTAL_CW[version] - ECC_CW[version] * ECC_BLOCKS[version];
}

function charCountBits(version: number): number {
  return version <= 9 ? 8 : 16;
}

function chooseVersion(byteLen: number): number {
  for (let v: number = 1; v <= 15; v++) {
    const bitsNeeded: number = 4 + charCountBits(v) + byteLen * 8;
    if (bitsNeeded <= dataCapacity(v) * 8) {
      return v;
    }
  }
  throw new Error('Text too long for QR versions 1–15 (ECC-M)');
}

function encodeData(bytes: number[], version: number): number[] {
  const buf: BitBuffer = new BitBuffer();
  buf.append(0x4, 4);
  buf.append(bytes.length, charCountBits(version));
  for (let i: number = 0; i < bytes.length; i++) {
    buf.append(bytes[i], 8);
  }

  const capacityBits: number = dataCapacity(version) * 8;
  const terminator: number = Math.min(4, capacityBits - buf.length);
  buf.append(0, terminator);
  while (buf.length % 8 !== 0) {
    buf.append(0, 1);
  }

  const dataBytes: number[] = buf.toBytes();
  let padToggle: number = 0;
  while (dataBytes.length < dataCapacity(version)) {
    dataBytes.push(padToggle === 0 ? 0xEC : 0x11);
    padToggle = 1 - padToggle;
  }
  return dataBytes;
}

function interleave(data: number[], version: number): number[] {
  const blocks: number = ECC_BLOCKS[version];
  const ecPerBlock: number = ECC_CW[version];
  const total: number = TOTAL_CW[version];
  const dataTotal: number = total - ecPerBlock * blocks;
  const shortBlocks: number = blocks - (total % blocks);
  const shortLen: number = Math.floor(dataTotal / blocks);
  const longLen: number = shortLen + 1;

  const dataBlocks: number[][] = [];
  const ecBlocks: number[][] = [];
  let offset: number = 0;
  for (let i: number = 0; i < blocks; i++) {
    const len: number = i < shortBlocks ? shortLen : longLen;
    const block: number[] = data.slice(offset, offset + len);
    offset += len;
    dataBlocks.push(block);
    ecBlocks.push(rsEncode(block, ecPerBlock));
  }

  const result: number[] = [];
  for (let i: number = 0; i < longLen; i++) {
    for (let b: number = 0; b < blocks; b++) {
      if (i < dataBlocks[b].length) {
        result.push(dataBlocks[b][i]);
      }
    }
  }
  for (let i: number = 0; i < ecPerBlock; i++) {
    for (let b: number = 0; b < blocks; b++) {
      result.push(ecBlocks[b][i]);
    }
  }
  return result;
}

// ---- Matrix ----

function sizeOf(version: number): number {
  return version * 4 + 17;
}

function makeMatrix(n: number): number[][] {
  const m: number[][] = [];
  for (let r: number = 0; r < n; r++) {
    const row: number[] = [];
    for (let c: number = 0; c < n; c++) {
      row.push(-1);
    }
    m.push(row);
  }
  return m;
}

function copyMatrix(src: number[][]): number[][] {
  const out: number[][] = [];
  for (let r: number = 0; r < src.length; r++) {
    out.push(src[r].slice());
  }
  return out;
}

function placeFinder(m: number[][], row: number, col: number, n: number): void {
  for (let r: number = -1; r <= 7; r++) {
    for (let c: number = -1; c <= 7; c++) {
      const rr: number = row + r;
      const cc: number = col + c;
      if (rr < 0 || rr >= n || cc < 0 || cc >= n) {
        continue;
      }
      if ((r >= 0 && r <= 6 && (c === 0 || c === 6)) ||
        (c >= 0 && c <= 6 && (r === 0 || r === 6)) ||
        (r >= 2 && r <= 4 && c >= 2 && c <= 4)) {
        m[rr][cc] = 1;
      } else {
        m[rr][cc] = 0;
      }
    }
  }
}

function placeTiming(m: number[][], n: number): void {
  for (let i: number = 8; i < n - 8; i++) {
    const v: number = i % 2 === 0 ? 1 : 0;
    if (m[6][i] === -1) {
      m[6][i] = v;
    }
    if (m[i][6] === -1) {
      m[i][6] = v;
    }
  }
}

function placeAlign(m: number[][], version: number): void {
  const pos: number[] = ALIGN_POS[version];
  for (let i: number = 0; i < pos.length; i++) {
    for (let j: number = 0; j < pos.length; j++) {
      const r: number = pos[i];
      const c: number = pos[j];
      if (m[r][c] !== -1) {
        continue;
      }
      for (let dr: number = -2; dr <= 2; dr++) {
        for (let dc: number = -2; dc <= 2; dc++) {
          if (Math.abs(dr) === 2 || Math.abs(dc) === 2 || (dr === 0 && dc === 0)) {
            m[r + dr][c + dc] = 1;
          } else {
            m[r + dr][c + dc] = 0;
          }
        }
      }
    }
  }
}

function reserveFormat(m: number[][], n: number): void {
  for (let i: number = 0; i < 9; i++) {
    if (m[8][i] === -1) {
      m[8][i] = 0;
    }
    if (m[i][8] === -1) {
      m[i][8] = 0;
    }
  }
  for (let i: number = 0; i < 8; i++) {
    if (m[8][n - 1 - i] === -1) {
      m[8][n - 1 - i] = 0;
    }
    if (m[n - 1 - i][8] === -1) {
      m[n - 1 - i][8] = 0;
    }
  }
  m[n - 8][8] = 1;
}

function reserveVersion(m: number[][], version: number, n: number): void {
  if (version < 7) {
    return;
  }
  for (let i: number = 0; i < 6; i++) {
    for (let j: number = 0; j < 3; j++) {
      m[i][n - 11 + j] = 0;
      m[n - 11 + j][i] = 0;
    }
  }
}

function placeFunctionPatterns(m: number[][], version: number, n: number): void {
  placeFinder(m, 0, 0, n);
  placeFinder(m, 0, n - 7, n);
  placeFinder(m, n - 7, 0, n);
  placeAlign(m, version);
  placeTiming(m, n);
  reserveFormat(m, n);
  reserveVersion(m, version, n);
}

function placeData(m: number[][], codewords: number[], n: number): void {
  let bitIdx: number = 0;
  const totalBits: number = codewords.length * 8;
  let upward: boolean = true;

  for (let col: number = n - 1; col > 0; col -= 2) {
    if (col === 6) {
      col = 5;
    }
    for (let i: number = 0; i < n; i++) {
      const row: number = upward ? n - 1 - i : i;
      for (let c: number = 0; c < 2; c++) {
        const cc: number = col - c;
        if (m[row][cc] !== -1) {
          continue;
        }
        let bit: number = 0;
        if (bitIdx < totalBits) {
          const byte: number = codewords[bitIdx >>> 3];
          bit = (byte >>> (7 - (bitIdx & 7))) & 1;
          bitIdx++;
        }
        m[row][cc] = bit;
      }
    }
    upward = !upward;
  }
}

function applyMask(m: number[][], mask: number, n: number, reserved: boolean[][]): void {
  for (let r: number = 0; r < n; r++) {
    for (let c: number = 0; c < n; c++) {
      if (reserved[r][c]) {
        continue;
      }
      let invert: boolean = false;
      switch (mask) {
        case 0:
          invert = ((r + c) & 1) === 0;
          break;
        case 1:
          invert = (r & 1) === 0;
          break;
        case 2:
          invert = c % 3 === 0;
          break;
        case 3:
          invert = (r + c) % 3 === 0;
          break;
        case 4:
          invert = (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0;
          break;
        case 5:
          invert = (r * c) % 2 + (r * c) % 3 === 0;
          break;
        case 6:
          invert = ((r * c) % 2 + (r * c) % 3) % 2 === 0;
          break;
        case 7:
          invert = ((r + c) % 2 + (r * c) % 3) % 2 === 0;
          break;
        default:
          break;
      }
      if (invert) {
        m[r][c] ^= 1;
      }
    }
  }
}

function placeFormat(m: number[][], mask: number, n: number): void {
  const bits: number = FORMAT_BITS[mask];
  for (let i: number = 0; i < 15; i++) {
    const bit: number = (bits >>> i) & 1;
    // Near top-left finder
    if (i < 6) {
      m[8][i] = bit;
    } else if (i < 8) {
      m[8][i + 1] = bit;
    } else if (i === 8) {
      m[7][8] = bit;
    } else {
      m[14 - i][8] = bit;
    }
    // Timing-adjacent / far copies
    if (i < 8) {
      m[n - 1 - i][8] = bit;
    } else {
      m[8][n - 15 + i] = bit;
    }
  }
  m[n - 8][8] = 1;
}

function placeVersionInfo(m: number[][], version: number, n: number): void {
  if (version < 7) {
    return;
  }
  const bits: number = VERSION_BITS[version];
  for (let i: number = 0; i < 18; i++) {
    const bit: number = (bits >>> i) & 1;
    const a: number = n - 11 + (i % 3);
    const b: number = Math.floor(i / 3);
    m[a][b] = bit;
    m[b][a] = bit;
  }
}

function maskPenalty(m: number[][], n: number): number {
  let penalty: number = 0;

  for (let r: number = 0; r < n; r++) {
    let run: number = 1;
    for (let c: number = 1; c < n; c++) {
      if (m[r][c] === m[r][c - 1]) {
        run++;
        if (run === 5) {
          penalty += 3;
        } else if (run > 5) {
          penalty++;
        }
      } else {
        run = 1;
      }
    }
  }
  for (let c: number = 0; c < n; c++) {
    let run: number = 1;
    for (let r: number = 1; r < n; r++) {
      if (m[r][c] === m[r - 1][c]) {
        run++;
        if (run === 5) {
          penalty += 3;
        } else if (run > 5) {
          penalty++;
        }
      } else {
        run = 1;
      }
    }
  }

  for (let r: number = 0; r < n - 1; r++) {
    for (let c: number = 0; c < n - 1; c++) {
      const v: number = m[r][c];
      if (v === m[r][c + 1] && v === m[r + 1][c] && v === m[r + 1][c + 1]) {
        penalty += 3;
      }
    }
  }

  for (let r: number = 0; r < n; r++) {
    for (let c: number = 0; c <= n - 7; c++) {
      if (m[r][c] === 1 && m[r][c + 1] === 0 && m[r][c + 2] === 1 &&
        m[r][c + 3] === 1 && m[r][c + 4] === 1 && m[r][c + 5] === 0 && m[r][c + 6] === 1) {
        penalty += 40;
      }
    }
  }
  for (let c: number = 0; c < n; c++) {
    for (let r: number = 0; r <= n - 7; r++) {
      if (m[r][c] === 1 && m[r + 1][c] === 0 && m[r + 2][c] === 1 &&
        m[r + 3][c] === 1 && m[r + 4][c] === 1 && m[r + 5][c] === 0 && m[r + 6][c] === 1) {
        penalty += 40;
      }
    }
  }

  let dark: number = 0;
  for (let r: number = 0; r < n; r++) {
    for (let c: number = 0; c < n; c++) {
      if (m[r][c] === 1) {
        dark++;
      }
    }
  }
  const total: number = n * n;
  const k: number = Math.floor(Math.abs(dark * 20 - total * 10) / total);
  penalty += k * 10;
  return penalty;
}

function buildMatrix(text: string): number[][] {
  const bytes: number[] = toUtf8Bytes(text);
  const version: number = chooseVersion(bytes.length);
  const n: number = sizeOf(version);
  const data: number[] = encodeData(bytes, version);
  const codewords: number[] = interleave(data, version);

  const m: number[][] = makeMatrix(n);
  placeFunctionPatterns(m, version, n);
  placeData(m, codewords, n);

  const reserved: boolean[][] = [];
  const func: number[][] = makeMatrix(n);
  placeFunctionPatterns(func, version, n);
  for (let r: number = 0; r < n; r++) {
    const row: boolean[] = [];
    for (let c: number = 0; c < n; c++) {
      row.push(func[r][c] !== -1);
    }
    reserved.push(row);
  }

  let bestPenalty: number = 0x7FFFFFFF;
  let bestMatrix: number[][] = m;

  for (let mask: number = 0; mask < 8; mask++) {
    const candidate: number[][] = copyMatrix(m);
    applyMask(candidate, mask, n, reserved);
    placeFormat(candidate, mask, n);
    placeVersionInfo(candidate, version, n);
    const pen: number = maskPenalty(candidate, n);
    if (pen < bestPenalty) {
      bestPenalty = pen;
      bestMatrix = candidate;
    }
  }
  return bestMatrix;
}

// ---- Base64 (local, no Buffer) ----

const B64: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function base64Encode(input: string): string {
  const bytes: number[] = toUtf8Bytes(input);
  let out: string = '';
  for (let i: number = 0; i < bytes.length; i += 3) {
    const b0: number = bytes[i];
    const b1: number = i + 1 < bytes.length ? bytes[i + 1] : 0;
    const b2: number = i + 2 < bytes.length ? bytes[i + 2] : 0;
    out += B64.charAt(b0 >> 2);
    out += B64.charAt(((b0 & 3) << 4) | (b1 >> 4));
    out += i + 1 < bytes.length ? B64.charAt(((b1 & 15) << 2) | (b2 >> 6)) : '=';
    out += i + 2 < bytes.length ? B64.charAt(b2 & 63) : '=';
  }
  return out;
}

// ---- Public API ----

/**
 * Generate a QR code as SVG markup.
 * @param text Payload (e.g. otpauth URI)
 * @param moduleSize Pixel size of one QR module (default 4)
 */
export function createQrSvg(text: string, moduleSize: number = 4): string {
  const matrix: number[][] = buildMatrix(text);
  const n: number = matrix.length;
  const quiet: number = 4;
  const dim: number = (n + quiet * 2) * moduleSize;
  const parts: string[] = [];
  parts.push(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${dim}" height="${dim}" viewBox="0 0 ${dim} ${dim}" shape-rendering="crispEdges">`
  );
  parts.push(`<rect width="${dim}" height="${dim}" fill="#ffffff"/>`);
  for (let r: number = 0; r < n; r++) {
    for (let c: number = 0; c < n; c++) {
      if (matrix[r][c] === 1) {
        const x: number = (c + quiet) * moduleSize;
        const y: number = (r + quiet) * moduleSize;
        parts.push(`<rect x="${x}" y="${y}" width="${moduleSize}" height="${moduleSize}" fill="#000000"/>`);
      }
    }
  }
  parts.push('</svg>');
  return parts.join('');
}

/**
 * Generate a QR code as a base64 SVG data URI (for Image src).
 */
export function createQrSvgDataUri(text: string): string {
  const svg: string = createQrSvg(text, 4);
  return `data:image/svg+xml;base64,${base64Encode(svg)}`;
}
