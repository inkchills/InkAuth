// Hotp.ets — aligned with Stratum.Core/src/Generator/Hotp.cs

import { IGenerator } from './IGenerator';
import { HashAlgorithm } from './HashAlgorithm';
import { SecretUtil } from '../util/SecretUtil';
import { HmacUtil } from '../util/HmacUtil';

export class Hotp implements IGenerator {
  private secret: string;
  private algorithm: HashAlgorithm;
  private digits: number;

  constructor(secret: string, algorithm: HashAlgorithm, digits: number) {
    this.secret = SecretUtil.normalizeBase32(secret);
    this.algorithm = algorithm;
    this.digits = digits;
  }

  async compute(counter: number): Promise<string> {
    const secretBytes = SecretUtil.base32ToBytes(this.secret);
    const hmac = await HmacUtil.hmac(this.algorithm, secretBytes, HmacUtil.counterBytes(counter));
    const material = HmacUtil.dynamicTruncate31(hmac);
    const otp = material % Math.pow(10, this.digits);
    return otp.toString().padStart(this.digits, '0');
  }
}
