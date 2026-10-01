import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import  { HashAlgorithm } from '../Enums/HashAlgorithm'
import { IGenerator } from './IGenerator'

/**
 * Base32解码工具类
 */
class Base32Decoder {
  private static readonly RFC4648_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  private static readonly RFC4648_ALPHABET_MAP: Map<string, number> = (() => {
    const map = new Map<string, number>();
    for (let i = 0; i < Base32Decoder.RFC4648_ALPHABET.length; i++) {
      map.set(Base32Decoder.RFC4648_ALPHABET.charAt(i), i);
    }
    return map;
  })();

  /**
   * 解码Base32字符串为Uint8Array
   * @param input Base32编码的字符串
   * @returns 解码后的字节数组
   */
  public static decode(input: string): Uint8Array {
    // 移除空格和填充字符
    const cleanedInput = input.toUpperCase().replace(/[=\s]/g, '');

    if (cleanedInput.length === 0) {
      return new Uint8Array(0);
    }

    // 计算输出字节长度
    const outputLength = Math.floor(cleanedInput.length * 5 / 8);
    const output = new Uint8Array(outputLength);

    let buffer = 0;
    let bitsLeft = 0;
    let outputIndex = 0;

    for (let i = 0; i < cleanedInput.length; i++) {
      const char = cleanedInput.charAt(i);
      const value = Base32Decoder.RFC4648_ALPHABET_MAP.get(char);

      if (value === undefined) {
        // 抛出Error类型而不是string
        throw new Error(`无效的Base32字符: ${char}`);
      }

      buffer = (buffer << 5) | value;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output[outputIndex++] = (buffer >> bitsLeft) & 0xFF;
      }
    }

    return output;
  }
}

/**
 * HMAC-OTP抽象基类
 */
export abstract class HmacOtp implements IGenerator {
  private hmacKey: cryptoFramework.SymKey | null = null;
  protected readonly digits: number;
  private readonly algorithm: HashAlgorithm;
  private isDisposed: boolean = false;

  /**
   * 构造函数
   * @param secret Base32编码的密钥
   * @param algorithm 哈希算法
   * @param digits 生成的OTP位数
   */
  protected constructor(secret: string, algorithm: HashAlgorithm, digits: number) {
    this.algorithm = algorithm;
    this.digits = digits;

    // 解码Base32密钥
    try {
      const secretBytes = Base32Decoder.decode(secret);
      this.initHmacKey(secretBytes).catch((error: BusinessError) => {
        console.error(`初始化HMAC密钥失败: ${error.code}, ${error.message}`);
      });
    } catch (error) {
      // 将任何捕获的错误转换为Error类型
      if (error instanceof Error) {
        throw error;
      } else {
        throw new Error(`Base32解码失败: ${error}`);
      }
    }
  }

  /**
   * 初始化HMAC密钥
   * @param keyBytes 密钥字节数组
   */
  private async initHmacKey(keyBytes: Uint8Array): Promise<void> {
    try {
      // 创建对称密钥生成器
      const symKeyGenerator = cryptoFramework.createSymKeyGenerator(this.getAlgorithmString());

      // 转换密钥材料
      const keyBlob: cryptoFramework.DataBlob = {
        data: keyBytes
      };

      // 生成对称密钥
      this.hmacKey = await symKeyGenerator.convertKey(keyBlob);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`初始化HMAC密钥失败: ${err.code}, ${err.message}`);
      // 抛出Error类型
      throw new Error(`初始化HMAC密钥失败: ${err.code}, ${err.message}`);
    }
  }

  /**
   * 获取算法字符串
   * @returns 算法字符串
   */
  private getAlgorithmString(): string {
    switch (this.algorithm) {
      case HashAlgorithm.SHA1:
        return 'HMAC|SHA1';
      case HashAlgorithm.SHA256:
        return 'HMAC|SHA256';
      case HashAlgorithm.SHA512:
        return 'HMAC|SHA512';
      default:
        throw new Error(`不支持的哈希算法: ${this.algorithm}`);
    }
  }

  /**
   * 计算HMAC
   * @param counter 计数器字节数组
   * @returns 计算结果的整数表示
   */
  protected async computeHmac(counter: Uint8Array): Promise<number> {
    if (this.isDisposed) {
      throw new Error('对象已释放');
    }

    if (!this.hmacKey) {
      throw new Error('HMAC密钥未初始化');
    }

    try {
      // 创建MAC
      const mac = cryptoFramework.createMac(this.getAlgorithmString());

      // 初始化MAC
      await mac.init(this.hmacKey);

      // 更新数据
      const dataBlob: cryptoFramework.DataBlob = {
        data: counter
      };
      await mac.update(dataBlob);

      // 执行计算
      const hashResult = await mac.doFinal();

      // 动态偏移截断（与C#实现一致）
      const hashBytes = new Uint8Array(hashResult.data);
      const offset = hashBytes[hashBytes.length - 1] & 0x0F;

      // 提取4字节动态密码材料
      if (offset + 4 > hashBytes.length) {
        throw new Error('HMAC哈希长度不足');
      }

      return ((hashBytes[offset] & 0x7F) << 24) |
        ((hashBytes[offset + 1] & 0xFF) << 16) |
        ((hashBytes[offset + 2] & 0xFF) << 8) |
        ((hashBytes[offset + 3] & 0xFF));
    } catch (error) {
      const err = error as BusinessError;
      console.error(`计算HMAC失败: ${err.code}, ${err.message}`);
      // 抛出Error类型
      throw new Error(`计算HMAC失败: ${err.code}, ${err.message}`);
    }
  }

  /**
   * 截断为指定长度的OTP
   * @param material 原始密码材料
   * @returns 截断后的OTP字符串
   */
  protected truncate(material: number): string {
    // 计算10^digits
    const modulus = Math.pow(10, this.digits);

    // 取模并格式化为指定位数
    const otpValue = material % modulus;

    // 补零格式化
    return otpValue.toString().padStart(this.digits, '0');
  }

  /**
   * 释放资源
   */
  public dispose(): void {
    if (this.isDisposed) {
      return;
    }

    // 在ArkTS中，SymKey对象没有显式的dispose方法
    // 但我们可以将引用置空以便垃圾回收
    this.hmacKey = null;
    this.isDisposed = true;
  }

  /**
   * 检查参数有效性
   * @param digits OTP位数
   * @param timeStep 时间步长（仅TOTP）
   */
  protected validateParameters(digits: number, timeStep?: number): void {
    if (digits < 4 || digits > 10) {
      throw new Error(`OTP位数必须在4到10之间，当前: ${digits}`);
    }

    if (timeStep !== undefined && timeStep <= 0) {
      throw new Error(`时间步长必须大于0，当前: ${timeStep}`);
    }
  }

  /**
   * 实现IGenerator接口的compute方法
   * @param counter 计数器值
   * @returns OTP字符串
   */
  abstract compute(counter: number): Promise<string>;

  /**
   * 获取OTP位数
   * @returns OTP位数
   */
  public getDigits(): number {
    return this.digits;
  }
}

/**
 * TOTP（基于时间的OTP）实现
 */
export class Totp extends HmacOtp {
  private readonly timeStep: number; // 时间步长（秒）

  constructor(secret: string, algorithm: HashAlgorithm, digits: number = 6, timeStep: number = 30) {
    // 验证参数
    super(secret, algorithm, digits);
    if (timeStep <= 0) {
      throw new Error(`时间步长必须大于0，当前: ${timeStep}`);
    }
    this.timeStep = timeStep;
  }

  /**
   * 生成当前时间的TOTP
   * @param timestamp 可选时间戳（毫秒），默认当前时间
   * @returns TOTP字符串
   */
  public async generate(timestamp?: number): Promise<string> {
    const currentTime = timestamp ?? Date.now();
    const counter = this.getTimeCounter(currentTime);
    const material = await this.computeHmac(counter);
    return this.truncate(material);
  }

  /**
   * 验证TOTP
   * @param code 待验证的OTP
   * @param timestamp 可选时间戳（毫秒），默认当前时间
   * @param window 时间窗口大小，允许的偏移步数
   * @returns 验证结果
   */
  public async verify(code: string, timestamp?: number, window: number = 1): Promise<boolean> {
    if (code.length !== this.getDigits()) {
      return false;
    }

    const currentTime = timestamp ?? Date.now();

    // 检查当前时间及其前后窗口
    for (let i = -window; i <= window; i++) {
      const testTime = currentTime + i * this.timeStep * 1000;
      const testCounter = this.getTimeCounter(testTime);
      const material = await this.computeHmac(testCounter);
      const testCode = this.truncate(material);

      if (testCode === code) {
        return true;
      }
    }

    return false;
  }

  /**
   * 获取时间计数器
   * @param timestamp 时间戳（毫秒）
   * @returns 计数器字节数组
   */
  private getTimeCounter(timestamp: number): Uint8Array {
    // 计算时间步数
    const timeStepCount = Math.floor(timestamp / 1000 / this.timeStep);

    // 转换为8字节的大端序字节数组
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setUint32(0, 0); // 前4字节通常为0
    view.setUint32(4, timeStepCount);

    return new Uint8Array(buffer);
  }

  /**
   * 获取时间步长
   */
  public getTimeStep(): number {
    return this.timeStep;
  }

  /**
   * 获取OTP位数
   */
  public getDigits(): number {
    return this.digits;
  }

  /**
   * 实现IGenerator接口的compute方法
   * @param counter 计数器值
   * @returns OTP字符串
   */
  public async compute(counter: number): Promise<string> {
    const counterBytes = this.getCounterBytesForValue(counter);
    const material = await this.computeHmac(counterBytes);
    return this.truncate(material);
  }

  /**
   * 获取指定计数器的字节表示
   * @param counter 计数器值
   * @returns 计数器字节数组
   */
  private getCounterBytesForValue(counter: number): Uint8Array {
    // 转换为8字节的大端序字节数组
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setUint32(0, 0); // 前4字节通常为0
    view.setUint32(4, counter);

    return new Uint8Array(buffer);
  }
}

/**
 * HOTP（基于计数器的OTP）实现
 */
export class Hotp extends HmacOtp {
  private counter: number = 0;

  constructor(secret: string, algorithm: HashAlgorithm, digits: number = 6, initialCounter: number = 0) {
    super(secret, algorithm, digits);
    if (initialCounter < 0) {
      throw new Error(`初始计数器必须为非负数，当前: ${initialCounter}`);
    }
    this.counter = initialCounter;
  }

  /**
   * 生成下一个HOTP
   * @returns HOTP字符串
   */
  public async generate(): Promise<string> {
    const counterBytes = this.getCounterBytes();
    const material = await this.computeHmac(counterBytes);
    this.counter++;
    return this.truncate(material);
  }

  /**
   * 获取指定计数器的HOTP
   * @param counter 计数器值
   * @returns HOTP字符串
   */
  public async generateAt(counter: number): Promise<string> {
    if (counter < 0) {
      throw new Error(`计数器必须为非负数，当前: ${counter}`);
    }
    const counterBytes = this.getCounterBytesForValue(counter);
    const material = await this.computeHmac(counterBytes);
    return this.truncate(material);
  }

  /**
   * 验证HOTP
   * @param code 待验证的OTP
   * @param counter 验证的计数器值
   * @returns 验证结果
   */
  public async verify(code: string, counter: number): Promise<boolean> {
    if (code.length !== this.getDigits()) {
      return false;
    }

    if (counter < 0) {
      return false;
    }

    const counterBytes = this.getCounterBytesForValue(counter);
    const material = await this.computeHmac(counterBytes);
    const testCode = this.truncate(material);

    return testCode === code;
  }

  /**
   * 获取当前计数器的字节表示
   * @returns 计数器字节数组
   */
  private getCounterBytes(): Uint8Array {
    return this.getCounterBytesForValue(this.counter);
  }

  /**
   * 获取指定计数器的字节表示
   * @param counter 计数器值
   * @returns 计数器字节数组
   */
  private getCounterBytesForValue(counter: number): Uint8Array {
    // 转换为8字节的大端序字节数组
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setUint32(0, 0); // 前4字节通常为0
    view.setUint32(4, counter);

    return new Uint8Array(buffer);
  }

  /**
   * 获取当前计数器值
   */
  public getCounter(): number {
    return this.counter;
  }

  /**
   * 设置计数器值
   * @param value 新的计数器值
   */
  public setCounter(value: number): void {
    if (value < 0) {
      throw new Error(`计数器必须为非负数，当前: ${value}`);
    }
    this.counter = value;
  }

  /**
   * 实现IGenerator接口的compute方法
   * @param counter 计数器值
   * @returns OTP字符串
   */
  public async compute(counter: number): Promise<string> {
    const counterBytes = this.getCounterBytesForValue(counter);
    const material = await this.computeHmac(counterBytes);
    return this.truncate(material);
  }
}

/**
 * HMAC-OTP工厂类
 */
export class HmacOtpFactory {
  /**
   * 创建TOTP实例
   * @param secret Base32编码的密钥
   * @param algorithm 哈希算法，默认为SHA1
   * @param digits OTP位数，默认为6
   * @param timeStep 时间步长（秒），默认为30
   * @returns TOTP实例
   */
  public static createTotp(
    secret: string,
    algorithm: HashAlgorithm = HashAlgorithm.SHA1,
    digits: number = 6,
    timeStep: number = 30
  ): Totp {
    return new Totp(secret, algorithm, digits, timeStep);
  }

  /**
   * 创建HOTP实例
   * @param secret Base32编码的密钥
   * @param algorithm 哈希算法，默认为SHA1
   * @param digits OTP位数，默认为6
   * @param initialCounter 初始计数器值，默认为0
   * @returns HOTP实例
   */
  public static createHotp(
    secret: string,
    algorithm: HashAlgorithm = HashAlgorithm.SHA1,
    digits: number = 6,
    initialCounter: number = 0
  ): Hotp {
    return new Hotp(secret, algorithm, digits, initialCounter);
  }

  /**
   * 生成随机Base32密钥
   * @param bytes 密钥字节长度，默认为20（对应SHA1的160位）
   * @returns Base32编码的密钥
   */
  public static generateRandomSecret(bytes: number = 20): string {
    if (bytes <= 0) {
      throw new Error(`密钥字节长度必须大于0，当前: ${bytes}`);
    }

    // 生成随机字节
    const randomBytes = new Uint8Array(bytes);
    for (let i = 0; i < bytes; i++) {
      randomBytes[i] = Math.floor(Math.random() * 256);
    }

    // 简单转换为Base32（实际生产环境应使用更完善的Base32编码）
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    let result = '';

    let buffer = 0;
    let bitsLeft = 0;

    for (let i = 0; i < randomBytes.length; i++) {
      buffer = (buffer << 8) | randomBytes[i];
      bitsLeft += 8;

      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        const index = (buffer >> bitsLeft) & 0x1F;
        result += alphabet.charAt(index);
      }
    }

    if (bitsLeft > 0) {
      buffer <<= (5 - bitsLeft);
      const index = buffer & 0x1F;
      result += alphabet.charAt(index);
    }

    // 添加填充字符
    while (result.length % 8 !== 0) {
      result += '=';
    }

    return result;
  }
}

/**
 * MobileOtp（基于移动的OTP）实现
 */
export class MobileOtp implements IGenerator {
  private readonly secret: string;
  private readonly pin: string;

  constructor(secret: string, pin: string) {
    this.secret = secret;
    this.pin = pin;
  }

  /**
   * 实现IGenerator接口的compute方法
   * @param counter 计数器值
   * @returns OTP字符串
   */
  public async compute(counter: number): Promise<string> {
    // MobileOtp实现逻辑
    // 这里简化实现，实际应该使用正确的算法
    const secretBytes = Base32Decoder.decode(this.secret);
    // 模拟生成OTP
    return Math.floor(Math.random() * 1000000).toString().padStart(6, '0');
  }
}

/**
 * SteamOtp（Steam平台OTP）实现
 */
export class SteamOtp extends HmacOtp {
  constructor(secret: string) {
    // Steam OTP使用SHA1算法，5位数字
    super(secret, HashAlgorithm.SHA1, 5);
  }

  /**
   * 实现IGenerator接口的compute方法
   * @param counter 计数器值
   * @returns OTP字符串
   */
  public async compute(counter: number): Promise<string> {
    const counterBytes = this.getCounterBytesForValue(counter);
    const material = await this.computeHmac(counterBytes);
    return this.truncate(material);
  }

  /**
   * 获取指定计数器的字节表示
   * @param counter 计数器值
   * @returns 计数器字节数组
   */
  private getCounterBytesForValue(counter: number): Uint8Array {
    // 转换为8字节的大端序字节数组
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setUint32(0, 0); // 前4字节通常为0
    view.setUint32(4, counter);

    return new Uint8Array(buffer);
  }
}

/**
 * YandexOtp（Yandex平台OTP）实现
 */
export class YandexOtp extends HmacOtp {
  private readonly pin: string;

  constructor(secret: string, pin: string) {
    // Yandex OTP使用SHA1算法，6位数字
    super(secret, HashAlgorithm.SHA1, 6);
    this.pin = pin;
  }

  /**
   * 实现IGenerator接口的compute方法
   * @param counter 计数器值
   * @returns OTP字符串
   */
  public async compute(counter: number): Promise<string> {
    const counterBytes = this.getCounterBytesForValue(counter);
    const material = await this.computeHmac(counterBytes);
    return this.truncate(material);
  }

  /**
   * 获取指定计数器的字节表示
   * @param counter 计数器值
   * @returns 计数器字节数组
   */
  private getCounterBytesForValue(counter: number): Uint8Array {
    // 转换为8字节的大端序字节数组
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setUint32(0, 0); // 前4字节通常为0
    view.setUint32(4, counter);

    return new Uint8Array(buffer);
  }
}