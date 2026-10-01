// Totp.ets — aligned with Stratum.Core/src/Generator/Totp.cs

import { IGenerator } from './IGenerator';
import { HashAlgorithm } from './HashAlgorithm';
import { SecretUtil } from '../util/SecretUtil';
import { HmacUtil } from '../util/HmacUtil';

export class Totp implements IGenerator {
  private secret: string;
  private period: number;
  private algorithm: HashAlgorithm;
  private digits: number;

  constructor(secret: string, period: number, algorithm: HashAlgorithm, digits: number) {
    this.secret = SecretUtil.normalizeBase32(secret);
    this.period = period > 0 ? period : 30;
    this.algorithm = algorithm;
    this.digits = digits;
  }

  async compute(counter: number): Promise<string> {
    const material = await this.computeMaterial(counter);
    return this.finalise(material);
  }

  protected async computeMaterial(counter: number): Promise<number> {
    const window = Math.floor(counter / this.period);
    const secretBytes = SecretUtil.base32ToBytes(this.secret);
    const hmac = await HmacUtil.hmac(this.algorithm, secretBytes, HmacUtil.counterBytes(window));
    return HmacUtil.dynamicTruncate31(hmac);
  }

  protected finalise(material: number): string {
    const mod = Math.pow(10, this.digits);
    const otp = material % mod;
    return otp.toString().padStart(this.digits, '0');
  }
}
