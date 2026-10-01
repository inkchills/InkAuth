export  class Base32Util {
  static decode(input: string): Uint8Array {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    const cleaned = input.replace(/=+$/, '').toUpperCase();
    let bits = 0;
    let value = 0;
    let outputIndex = 0;

    const byteCount = Math.floor(cleaned.length * 5 / 8);
    const bytes = new Uint8Array(byteCount);

    for (const char of cleaned) {
      const index = alphabet.indexOf(char);
      if (index === -1) throw new Error('Invalid character');

      value = (value << 5) | index;
      bits += 5;

      if (bits >= 8) {
        bits -= 8;
        bytes[outputIndex++] = (value >>> bits) & 0xff;
      }
    }

    return bytes;
  }
}