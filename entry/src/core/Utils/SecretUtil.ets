import { AuthenticatorType, AuthenticatorTypeSpecification } from "../Enums/AuthenticatorType";
import { Base32Util } from "./Base32Util";

export class SecretUtil {
  // Yandex OTP 需要的字节长度
  private static readonly YANDEX_OTP_SECRET_BYTE_COUNT: number = 20;
  // mOTP 需要的最小字符长度
  private static readonly MOBILE_OTP_SECRET_MIN_LENGTH: number = 16;

  /**
   * 规范化密钥输入
   * @param input 原始密钥
   * @param type 认证器类型
   * @returns 规范化后的密钥
   */
  public static normalise(input: string, type: AuthenticatorType): string {
    if (!input) {
      return input;
    }

    let result = input;

    // 如果是Base32类型的密钥，转换为大写
    if (AuthenticatorTypeSpecification.hasBase32Secret(type)) {
      result = result.toUpperCase();
    }

    // 移除空格和连字符
    result = result.replace(/\s/g, '');
    result = result.replace(/-/g, '');

    return result;
  }

  /**
   * 验证密钥的有效性
   * @param secret 密钥
   * @param type 认证器类型
   * @throws {Error} 当密钥无效时抛出异常
   */
  public static validate(secret: string, type: AuthenticatorType): void {
    if (!secret || secret.trim().length === 0) {
      throw new Error("Secret cannot be null or empty");
    }

    const trimmedSecret = secret.trim();

    // 处理Base32类型的密钥
    if (AuthenticatorTypeSpecification.hasBase32Secret(type)) {
      let bytes: Uint8Array;

      try {
        // 先规范化再解码 - 使用类名调用静态方法
        const normalised = SecretUtil.normalise(trimmedSecret, type);
        bytes = Base32Util.decode(normalised);
      } catch (e) {
        // 将异常转换为字符串消息
        const errorMessage = e instanceof Error ? e.message : String(e);
        throw new Error(`Error decoding secret as base32: ${errorMessage}`);
      }

      if (bytes.length === 0) {
        throw new Error("Error decoding secret, output length 0");
      }

      // Yandex OTP 特殊处理
      if (type === AuthenticatorType.YandexOtp && bytes.length < SecretUtil.YANDEX_OTP_SECRET_BYTE_COUNT) {
        throw new Error(`Secret is too short for Yandex OTP, need at least ${SecretUtil.YANDEX_OTP_SECRET_BYTE_COUNT} bytes`);
      }
    }

    // mOTP 特殊处理
    if (type === AuthenticatorType.MobileOtp && trimmedSecret.length < SecretUtil.MOBILE_OTP_SECRET_MIN_LENGTH) {
      throw new Error(`Too few characters in secret for mOTP, need at least ${SecretUtil.MOBILE_OTP_SECRET_MIN_LENGTH} characters`);
    }
  }

  /**
   * 检查密钥是否为有效的Base32格式
   * @param secret 密钥
   * @returns 如果是有效的Base32格式返回true，否则返回false
   */
  public static isValidBase32(secret: string): boolean {
    if (!secret || secret.trim().length === 0) {
      return false;
    }

    try {
      const bytes = Base32Util.decode(secret);
      return bytes.length > 0;
    } catch (e) {
      return false;
    }
  }

  /**
   * 获取Base32解码后的字节数组
   * @param secret Base32编码的密钥
   * @returns 解码后的字节数组
   * @throws {Error} 当解码失败时抛出异常
   */
  public static decodeBase32Secret(secret: string): Uint8Array {
    if (!secret || secret.trim().length === 0) {
      throw new Error("Secret cannot be null or empty");
    }

    try {
      return Base32Util.decode(secret.trim().toUpperCase().replace(/\s/g, '').replace(/-/g, ''));
    } catch (e) {
      // 将异常转换为字符串消息
      const errorMessage = e instanceof Error ? e.message : String(e);
      throw new Error(`Failed to decode Base32 secret: ${errorMessage}`);
    }
  }
}