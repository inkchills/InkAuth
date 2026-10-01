// HmacOtp.ets — real HMAC-based OTP (replaces the placeholder XOR hash)

import { IGenerator } from './IGenerator';
import { HashAlgorithm } from './HashAlgorithm';
import { SecretUtil } from '../util/SecretUtil';
import { HmacUtil } from '../util/HmacUtil';

export class HmacOtp implements IGenerator {
  private readonly secret: string;
  private readonly algorithm: HashAlgorithm;
  private readonly digits: number;

  constructor(secret: string, algorithm: HashAlgorithm, digits: number) {
    this.secret = SecretUtil.normalizeBase32(secret);
    this.algorithm = algorithm;
    this.digits = digits;
  }

  public async compute(counter: number): Promise<string> {
    const secretBytes = SecretUtil.base32ToBytes(this.secret);
    const hmac = await HmacUtil.hmac(this.algorithm, secretBytes, HmacUtil.counterBytes(counter));
    const material = HmacUtil.dynamicTruncate31(hmac);
    const otp = material % Math.pow(10, this.digits);
    return otp.toString().padStart(this.digits, '0');
  }
}
