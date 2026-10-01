// SteamOtp.ets — aligned with Stratum.Core/src/Generator/SteamOtp.cs

import { IGenerator } from './IGenerator';
import { HashAlgorithm } from './HashAlgorithm';
import { SecretUtil } from '../util/SecretUtil';
import { HmacUtil } from '../util/HmacUtil';

export class SteamOtp implements IGenerator {
  public static readonly DIGITS: number = 5;
  private static readonly PERIOD: number = 30;
  private static readonly ALPHABET: string = '23456789BCDFGHJKMNPQRTVWXY';
  private secret: string;

  constructor(secret: string) {
    this.secret = SecretUtil.normalizeBase32(secret);
  }

  async compute(counter: number): Promise<string> {
    const window = Math.floor(counter / SteamOtp.PERIOD);
    const secretBytes = SecretUtil.base32ToBytes(this.secret);
    const hmac = await HmacUtil.hmac(HashAlgorithm.Sha1, secretBytes, HmacUtil.counterBytes(window));
    let material = HmacUtil.dynamicTruncate31(hmac);
    let result = '';
    for (let i = 0; i < SteamOtp.DIGITS; i++) {
      result += SteamOtp.ALPHABET.charAt(material % SteamOtp.ALPHABET.length);
      material = Math.floor(material / SteamOtp.ALPHABET.length);
    }
    return result;
  }
}
