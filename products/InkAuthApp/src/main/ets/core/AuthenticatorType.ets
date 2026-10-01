// AuthenticatorType.ets — internal enum stays 0-based; backup import maps Android 1-5.

export enum AuthenticatorType {
  Totp = 0,
  Hotp = 1,
  MobileOtp = 2,
  SteamOtp = 3,
  YandexOtp = 4
}

export enum GenerationMethod {
  Time = 0,
  Counter = 1
}

export class AuthenticatorTypeSpecification {
  public static getGenerationMethod(type: AuthenticatorType): GenerationMethod {
    return type === AuthenticatorType.Hotp ? GenerationMethod.Counter : GenerationMethod.Time;
  }

  public static hasBase32Secret(type: AuthenticatorType): boolean {
    return type !== AuthenticatorType.MobileOtp;
  }

  public static hasPin(type: AuthenticatorType): boolean {
    return type === AuthenticatorType.MobileOtp || type === AuthenticatorType.YandexOtp;
  }

  public static getDefaultPeriod(_type: AuthenticatorType): number {
    return 30;
  }

  public static getMinDigits(type: AuthenticatorType): number {
    switch (type) {
      case AuthenticatorType.SteamOtp:
        return 5;
      case AuthenticatorType.YandexOtp:
        return 8;
      default:
        return 6;
    }
  }

  public static getMaxDigits(type: AuthenticatorType): number {
    switch (type) {
      case AuthenticatorType.Hotp:
        return 8;
      case AuthenticatorType.Totp:
        return 10;
      case AuthenticatorType.SteamOtp:
        return 5;
      case AuthenticatorType.YandexOtp:
        return 8;
      default:
        return 6;
    }
  }
}
