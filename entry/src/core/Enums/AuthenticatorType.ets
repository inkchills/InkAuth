import {GenerationMethod} from './GenerationMethod'

export enum AuthenticatorType {
  Hotp = 1,
  Totp = 2,
  MobileOtp = 3,
  SteamOtp = 4,
  YandexOtp = 5
}

// 定义接口来明确对象字面量的类型
interface IMobileOtpConstants {
  Digits: number;
  PinLength: number;
}

interface ISteamOtpConstants {
  Digits: number;
}

interface IYandexOtpConstants {
  Digits: number;
}

// 使用接口类型声明常量对象
const MobileOtp: IMobileOtpConstants = {
  Digits: 6,
  PinLength: 4
};

const SteamOtp: ISteamOtpConstants = {
  Digits: 5
};

const YandexOtp: IYandexOtpConstants = {
  Digits: 6
};

// AuthenticatorType 工具类
export class AuthenticatorTypeSpecification {
  /**
   * 获取认证器的生成方法
   */
  static getGenerationMethod(type: AuthenticatorType): GenerationMethod {
    switch (type) {
      case AuthenticatorType.Hotp:
        return GenerationMethod.Counter;
      case AuthenticatorType.Totp:
      case AuthenticatorType.MobileOtp:
      case AuthenticatorType.SteamOtp:
      case AuthenticatorType.YandexOtp:
        return GenerationMethod.Time;
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }

  /**
   * 检查是否使用 Base32 密钥
   */
  static hasBase32Secret(type: AuthenticatorType): boolean {
    switch (type) {
      case AuthenticatorType.Hotp:
      case AuthenticatorType.Totp:
      case AuthenticatorType.SteamOtp:
      case AuthenticatorType.YandexOtp:
        return true;
      case AuthenticatorType.MobileOtp:
        return false;
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }

  /**
   * 检查是否支持可变算法
   */
  static hasVariableAlgorithm(type: AuthenticatorType): boolean {
    switch (type) {
      case AuthenticatorType.Hotp:
      case AuthenticatorType.Totp:
        return true;
      case AuthenticatorType.MobileOtp:
      case AuthenticatorType.SteamOtp:
      case AuthenticatorType.YandexOtp:
        return false;
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }

  /**
   * 检查是否支持可变时间周期
   */
  static hasVariablePeriod(type: AuthenticatorType): boolean {
    switch (type) {
      case AuthenticatorType.Totp:
        return true;
      case AuthenticatorType.Hotp:
      case AuthenticatorType.MobileOtp:
      case AuthenticatorType.SteamOtp:
      case AuthenticatorType.YandexOtp:
        return false;
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }

  /**
   * 检查是否需要 PIN 码
   */
  static hasPin(type: AuthenticatorType): boolean {
    switch (type) {
      case AuthenticatorType.MobileOtp:
      case AuthenticatorType.YandexOtp:
        return true;
      case AuthenticatorType.Hotp:
      case AuthenticatorType.Totp:
      case AuthenticatorType.SteamOtp:
        return false;
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }

  /**
   * 获取默认时间周期（秒）
   */
  static getDefaultPeriod(type: AuthenticatorType): number {
    return 30;
  }

  /**
   * 获取默认数字位数
   */
  static getDefaultDigits(type: AuthenticatorType): number {
    return AuthenticatorTypeSpecification.getMinDigits(type);
  }

  /**
   * 获取最小数字位数
   */
  static getMinDigits(type: AuthenticatorType): number {
    switch (type) {
      case AuthenticatorType.Hotp:
      case AuthenticatorType.Totp:
        return 6;
      case AuthenticatorType.MobileOtp:
        return MobileOtp.Digits;
      case AuthenticatorType.SteamOtp:
        return SteamOtp.Digits;
      case AuthenticatorType.YandexOtp:
        return YandexOtp.Digits;
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }

  /**
   * 获取最大数字位数
   */
  static getMaxDigits(type: AuthenticatorType): number {
    switch (type) {
      case AuthenticatorType.Hotp:
        return 8;
      case AuthenticatorType.Totp:
        return 10;
      case AuthenticatorType.MobileOtp:
        return MobileOtp.Digits;
      case AuthenticatorType.SteamOtp:
        return SteamOtp.Digits;
      case AuthenticatorType.YandexOtp:
        return YandexOtp.Digits;
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }

  /**
   * 获取 PIN 码最小长度
   */
  static getMinPinLength(type: AuthenticatorType): number {
    switch (type) {
      case AuthenticatorType.MobileOtp:
        return MobileOtp.PinLength;
      case AuthenticatorType.YandexOtp:
        return 4;
      case AuthenticatorType.Hotp:
      case AuthenticatorType.Totp:
      case AuthenticatorType.SteamOtp:
        throw new Error(`认证器类型 ${type} 不支持 PIN 码`);
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }

  /**
   * 获取 PIN 码最大长度
   */
  static getMaxPinLength(type: AuthenticatorType): number {
    switch (type) {
      case AuthenticatorType.MobileOtp:
        return MobileOtp.PinLength;
      case AuthenticatorType.YandexOtp:
        return 16;
      case AuthenticatorType.Hotp:
      case AuthenticatorType.Totp:
      case AuthenticatorType.SteamOtp:
        throw new Error(`认证器类型 ${type} 不支持 PIN 码`);
      default:
        throw new Error(`不支持的认证器类型: ${type}`);
    }
  }
}