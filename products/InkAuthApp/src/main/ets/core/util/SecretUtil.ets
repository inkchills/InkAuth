// SecretUtil.ets — aligned with Stratum.Core/src/Util/SecretUtil.cs

import { AuthenticatorType, AuthenticatorTypeSpecification } from '../AuthenticatorType';

export class SecretUtil {
  public static normalize(input: string, type: AuthenticatorType): string {
    let value = input || '';
    if (AuthenticatorTypeSpecification.hasBase32Secret(type)) {
      value = value.toUpperCase();
    }
    return value.replace(/[ \-]/g, '');
  }

  public static normalizeBase32(input: string): string {
    return (input || '').toUpperCase().replace(/[ \-=]/g, '');
  }

  public static validate(secret: string, type: AuthenticatorType): void {
    if (!secret) {
      throw new Error('Secret cannot be null or empty');
    }

    if (AuthenticatorTypeSpecification.hasBase32Secret(type)) {
      const bytes = SecretUtil.base32ToBytes(SecretUtil.normalizeBase32(secret));
      if (bytes.length === 0) {
        throw new Error('Error decoding secret, output length 0');
      }
      if (type === AuthenticatorType.YandexOtp && bytes.length < 16) {
        throw new Error('Secret is too short for Yandex OTP');
      }
    }

    if (type === AuthenticatorType.MobileOtp && secret.length < 16) {
      throw new Error('Too few characters in secret for mOTP');
    }
  }

  public static base32ToBytes(base32: string): Uint8Array {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    const normalized = SecretUtil.normalizeBase32(base32);
    const bytes: number[] = [];
    let bits = 0;
    let value = 0;

    for (let i = 0; i < normalized.length; i++) {
      const index = alphabet.indexOf(normalized.charAt(i));
      if (index === -1) {
        throw new Error('Error decoding secret as base 32');
      }
      value = (value << 5) | index;
      bits += 5;
      if (bits >= 8) {
        bytes.push((value >> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }
    return new Uint8Array(bytes);
  }

  public static bytesToBase32(bytes: Uint8Array): string {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    let result = '';
    let bits = 0;
    let value = 0;

    for (let i = 0; i < bytes.length; i++) {
      value = (value << 8) | bytes[i];
      bits += 8;
      while (bits >= 5) {
        result += alphabet.charAt((value >> (bits - 5)) & 0x1f);
        bits -= 5;
      }
    }
    if (bits > 0) {
      result += alphabet.charAt((value << (5 - bits)) & 0x1f);
    }
    return result;
  }
}
