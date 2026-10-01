// MobileOtp.ets — aligned with Stratum.Core/src/Generator/MobileOtp.cs
// MD5(floor(counter/10) + secret + pin).hex[0..6]

import { IGenerator } from './IGenerator';
import { HmacUtil } from '../util/HmacUtil';

export class MobileOtp implements IGenerator {
  public static readonly SECRET_MIN_LENGTH: number = 16;
  public static readonly PIN_LENGTH: number = 4;
  public static readonly DIGITS: number = 6;

  private secret: string;
  private pin: string;

  constructor(secret: string, pin: string) {
    this.secret = secret;
    this.pin = pin;
  }

  async compute(counter: number): Promise<string> {
    const timestamp = Math.floor(counter / 10);
    const digest = await HmacUtil.md5Hex(`${timestamp}${this.secret}${this.pin}`);
    return digest.substring(0, MobileOtp.DIGITS);
  }
}
