// HmacUtil.ets — HMAC via CryptoArchitectureKit (Stratum HmacOtp equivalent)

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { HashAlgorithm } from '../generator/HashAlgorithm';

interface MacSpec {
  mac: string;
  key: string;
}

export class HmacUtil {
  public static async hmac(algorithm: HashAlgorithm, key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
    const specs = HmacUtil.specsFor(algorithm);
    let lastError: Error | null = null;
    for (let i = 0; i < specs.length; i++) {
      try {
        const mac = cryptoFramework.createMac(specs[i].mac);
        const generator = cryptoFramework.createSymKeyGenerator(specs[i].key);
        const symKey = await generator.convertKey({ data: key });
        await mac.init(symKey);
        await mac.update({ data: data });
        const result = await mac.doFinal();
        return result.data;
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
      }
    }
    throw lastError || new Error('HMAC computation failed');
  }

  public static async sha256(data: Uint8Array): Promise<Uint8Array> {
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: data });
    const digest = await md.digest();
    return digest.data;
  }

  public static async md5Hex(input: string): Promise<string> {
    const bytes = HmacUtil.utf8Encode(input);
    const md = cryptoFramework.createMd('MD5');
    await md.update({ data: bytes });
    const digest = await md.digest();
    return HmacUtil.bytesToHex(digest.data);
  }

  public static counterBytes(counter: number): Uint8Array {
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    let value = Math.floor(counter);
    if (value < 0) {
      value = 0;
    }
    for (let i = 7; i >= 0; i--) {
      view.setUint8(i, value & 0xff);
      value = Math.floor(value / 256);
    }
    return new Uint8Array(buffer);
  }

  public static dynamicTruncate31(hmac: Uint8Array): number {
    const offset = hmac[hmac.length - 1] & 0x0f;
    return ((hmac[offset] & 0x7f) << 24) |
      ((hmac[offset + 1] & 0xff) << 16) |
      ((hmac[offset + 2] & 0xff) << 8) |
      (hmac[offset + 3] & 0xff);
  }

  public static utf8Encode(value: string): Uint8Array {
    const buffer = new ArrayBuffer(value.length * 3);
    const view = new Uint8Array(buffer);
    let offset = 0;
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i);
      if (code < 0x80) {
        view[offset++] = code;
      } else if (code < 0x800) {
        view[offset++] = 0xC0 | (code >> 6);
        view[offset++] = 0x80 | (code & 0x3F);
      } else {
        view[offset++] = 0xE0 | (code >> 12);
        view[offset++] = 0x80 | ((code >> 6) & 0x3F);
        view[offset++] = 0x80 | (code & 0x3F);
      }
    }
    return view.slice(0, offset);
  }

  public static bytesToHex(bytes: Uint8Array): string {
    let out = '';
    for (let i = 0; i < bytes.length; i++) {
      const hex = bytes[i].toString(16);
      out += hex.length === 1 ? `0${hex}` : hex;
    }
    return out;
  }

  public static hexToBytes(hex: string): Uint8Array {
    const clean = hex.length % 2 === 0 ? hex : `0${hex}`;
    const out = new Uint8Array(clean.length / 2);
    for (let i = 0; i < out.length; i++) {
      out[i] = parseInt(clean.substring(i * 2, i * 2 + 2), 16);
    }
    return out;
  }

  private static specsFor(algorithm: HashAlgorithm): MacSpec[] {
    switch (algorithm) {
      case HashAlgorithm.Sha256:
        return [{ mac: 'HMACSHA256', key: 'HMACSHA256' }, { mac: 'SHA256', key: 'HMAC' }];
      case HashAlgorithm.Sha512:
        return [{ mac: 'HMACSHA512', key: 'HMACSHA512' }, { mac: 'SHA512', key: 'HMAC' }];
      default:
        return [{ mac: 'HMACSHA1', key: 'HMACSHA1' }, { mac: 'SHA1', key: 'HMAC' }];
    }
  }
}
