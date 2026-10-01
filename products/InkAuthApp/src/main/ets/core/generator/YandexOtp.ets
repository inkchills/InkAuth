// YandexOtp.ets — aligned with Stratum.Core/src/Generator/YandexOtp.cs

import { IGenerator } from './IGenerator';
import { HashAlgorithm } from './HashAlgorithm';
import { SecretUtil } from '../util/SecretUtil';
import { HmacUtil } from '../util/HmacUtil';

export class YandexOtp implements IGenerator {
  public static readonly DIGITS: number = 8;
  public static readonly SECRET_BYTE_COUNT: number = 16;
  private static readonly PERIOD: number = 30;
  private static readonly MODULUS: number = 208827064576; // 26^8, fits in JS safe integer

  private secret: string;
  private pin: string;

  constructor(secret: string, pin: string) {
    this.secret = SecretUtil.normalizeBase32(secret);
    this.pin = pin;
  }

  async compute(counter: number): Promise<string> {
    const key = await this.deriveKey();
    const window = Math.floor(counter / YandexOtp.PERIOD);
    const hmac = await HmacUtil.hmac(HashAlgorithm.Sha256, key, HmacUtil.counterBytes(window));
    return YandexOtp.finalise(YandexOtp.computeMaterial(hmac));
  }

  private async deriveKey(): Promise<Uint8Array> {
    const pinBytes = HmacUtil.utf8Encode(this.pin || '');
    const secretBytes = SecretUtil.base32ToBytes(this.secret);
    if (secretBytes.length < YandexOtp.SECRET_BYTE_COUNT) {
      throw new Error('Secret too short');
    }
    const combined = new Uint8Array(pinBytes.length + YandexOtp.SECRET_BYTE_COUNT);
    combined.set(pinBytes, 0);
    combined.set(secretBytes.slice(0, YandexOtp.SECRET_BYTE_COUNT), pinBytes.length);
    const hashed = await HmacUtil.sha256(combined);
    if (hashed[0] === 0 && hashed.length > 1) {
      return hashed.slice(1);
    }
    return hashed;
  }

  /**
   * C# does ReadInt64BigEndian(hash[offset..offset+8]) & long.MaxValue,
   * then material % 26^8. A JS Number cannot hold that 63-bit intermediate,
   * so reduce with 32-bit limbs instead.
   */
  private static computeMaterial(hash: Uint8Array): number {
    const offset = hash[hash.length - 1] & 0x0f;
    const high = ((hash[offset] & 0x7f) * 0x1000000) +
      (hash[offset + 1] * 0x10000) +
      (hash[offset + 2] * 0x100) +
      hash[offset + 3];
    const low = (hash[offset + 4] * 0x1000000) +
      (hash[offset + 5] * 0x10000) +
      (hash[offset + 6] * 0x100) +
      hash[offset + 7];
    return (YandexOtp.mulMod(high, 0x100000000, YandexOtp.MODULUS) + (low % YandexOtp.MODULUS)) %
      YandexOtp.MODULUS;
  }

  private static mulMod(left: number, right: number, modulus: number): number {
    let result = 0;
    let addend = left % modulus;
    let multiplier = right;
    while (multiplier > 0) {
      if (multiplier % 2 === 1) {
        result = (result + addend) % modulus;
      }
      addend = (addend * 2) % modulus;
      multiplier = Math.floor(multiplier / 2);
    }
    return result;
  }

  private static finalise(material: number): string {
    const chars: string[] = [];
    let value = material;
    for (let i = 0; i < YandexOtp.DIGITS; i++) {
      chars.push(String.fromCharCode('a'.charCodeAt(0) + (value % 26)));
      value = Math.floor(value / 26);
    }
    return chars.reverse().join('');
  }
}
