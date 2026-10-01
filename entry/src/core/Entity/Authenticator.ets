import { HashAlgorithm } from '../Enums/HashAlgorithm';
import { AuthenticatorType } from '../Enums/AuthenticatorType';
import { GenerationMethod } from '../Enums/GenerationMethod';
import { IGenerator } from '../Generator/IGenerator';
import { Totp, Hotp, MobileOtp, SteamOtp, YandexOtp } from '../Generator/HmacOtp';
import { SecretUtil } from '../Utils/SecretUtil';


// 使用接口声明TypeHelpers
export  class  TypeHelpers {
  static  getDefaultDigits(type: AuthenticatorType): number {
    // 返回默认位数
    return type === AuthenticatorType.SteamOtp ? 5 : 6;
  }

  static  getDefaultPeriod(type: AuthenticatorType): number {
    // 返回默认周期
    return 30;
  }

  static  getGenerationMethod(type: AuthenticatorType): GenerationMethod {
    // 返回生成方法
    switch (type) {
      case AuthenticatorType.Hotp:
        return GenerationMethod.Counter;
      default:
        return GenerationMethod.Time;
    }
  }

  static  getMinDigits(type: AuthenticatorType): number {
    // 返回最小位数
    return 6;
  }

  static  getMaxDigits(type: AuthenticatorType): number {
    // 返回最大位数
    return 8;
  }
};

// 主 Authenticator 类
export class Authenticator {
  // 常量
  static readonly IssuerMaxLength = 32;
  static readonly UsernameMaxLength = 40;
  static readonly DefaultAlgorithm = HashAlgorithm.SHA1;

  // 私有字段
  private _generator: IGenerator | null = null;
  private _lastCounter: number = 0;
  private _code: string | null = null;

  // 属性（对应于数据库字段）
  type: AuthenticatorType;
  icon: string | null = null;
  issuer: string;
  username: string | null = null;
  secret: string;
  pin: string | null = null;
  algorithm: HashAlgorithm;
  digits: number;
  period: number;
  counter: number = 0;
  copyCount: number = 0;
  ranking: number = 0;

  constructor(
    issuer: string,
    secret: string,
    type: AuthenticatorType = AuthenticatorType.Totp
  ) {
    this.issuer = issuer;
    this.secret = secret;
    this.type = type;
    this.algorithm = Authenticator.DefaultAlgorithm;
    this.digits = TypeHelpers.getDefaultDigits(type);
    this.period = TypeHelpers.getDefaultPeriod(type);
  }

  // 修改：合并两个getCode方法，使用可选参数
  async getCode(counter?: number): Promise<string> {
    // 如果未提供counter参数，则根据类型计算默认counter
    if (counter === undefined) {
      const generationMethod = TypeHelpers.getGenerationMethod(this.type);
      switch (generationMethod) {
        case GenerationMethod.Time:
          const now = Math.floor(Date.now() / 1000);
          counter = now - (now % this.period);
          break;

        case GenerationMethod.Counter:
          counter = this.counter;
          break;

        default:
          throw new Error("Unknown generation method");
      }
    }

    // 延迟初始化生成器
    if (!this._generator) {
      switch (this.type) {
        case AuthenticatorType.Totp:
          this._generator = new Totp(this.secret, this.algorithm, this.digits, this.period);
          break;
        case AuthenticatorType.Hotp:
          this._generator = new Hotp(this.secret, this.algorithm, this.digits, this.counter);
          break;
        case AuthenticatorType.MobileOtp:
          this._generator = new MobileOtp(this.secret, this.pin || "");
          break;
        case AuthenticatorType.SteamOtp:
          this._generator = new SteamOtp(this.secret);
          break;
        case AuthenticatorType.YandexOtp:
          this._generator = new YandexOtp(this.secret, this.pin || "");
          break;
        default:
          throw new Error("Unknown authenticator type");
      }
    }

    const generationMethod = TypeHelpers.getGenerationMethod(this.type);

    switch (generationMethod) {
      case GenerationMethod.Time:
        this._code = await this._generator!.compute(counter);
        break;

      case GenerationMethod.Counter:
        if (this._lastCounter === this.counter) {
          return this._code!;
        }
        this._code = await this._generator!.compute(this.counter);
        this._lastCounter = this.counter;
        break;
    }

    return this._code!;
  }

  // 获取 URI 的方法
  private getMotpUri(): string {
    const builder = ["motp://"];
    builder.push(this.issuer);
    builder.push(":");
    builder.push(this.username || "");
    builder.push("?secret=");
    builder.push(this.secret);

    return builder.join("");
  }

  private getOtpAuthUri(): string {
    let type: string;
    switch (this.type) {
      case AuthenticatorType.Hotp:
        type = "hotp";
        break;
      case AuthenticatorType.Totp:
      case AuthenticatorType.SteamOtp:
        type = "totp";
        break;
      case AuthenticatorType.YandexOtp:
        type = "yaotp";
        break;
      default:
        throw new Error("Unsupported authenticator type");
    }

    const issuerUsername = !this.username ? this.issuer : `${this.issuer}:${this.username}`;
    const encodedIssuerUsername = encodeURIComponent(issuerUsername);
    const encodedIssuer = encodeURIComponent(this.issuer);

    const uriParts = [
      `otpauth://${type}/${encodedIssuerUsername}`,
      `?secret=${this.secret}`,
      `&issuer=${encodedIssuer}`
    ];

    if (this.algorithm !== Authenticator.DefaultAlgorithm) {
      let algorithmName: string;
      switch (this.algorithm) {
        case HashAlgorithm.SHA256:
          algorithmName = "SHA256";
          break;
        case HashAlgorithm.SHA512:
          algorithmName = "SHA512";
          break;
        default:
          throw new Error("Unsupported algorithm");
      }
      uriParts.push(`&algorithm=${algorithmName}`);
    }

    if (this.digits !== TypeHelpers.getDefaultDigits(this.type)) {
      uriParts.push(`&digits=${this.digits}`);
    }

    switch (this.type) {
      case AuthenticatorType.Totp:
        if (this.period !== TypeHelpers.getDefaultPeriod(this.type)) {
          uriParts.push(`&period=${this.period}`);
        }
        break;

      case AuthenticatorType.Hotp:
        uriParts.push(`&counter=${this.counter}`);
        break;

      case AuthenticatorType.SteamOtp:
        if (this.issuer !== "Steam") {
          uriParts.push("&steam");
        }
        break;

      case AuthenticatorType.YandexOtp:
        if (this.pin) {
          uriParts.push(`&pin_length=${this.pin.length}`);
        }
        break;
    }

    return uriParts.join("");
  }

  getUri(): string {
    return this.type === AuthenticatorType.MobileOtp ? this.getMotpUri() : this.getOtpAuthUri();
  }

  validate(): void {
    if (!this.issuer || this.issuer.trim().length === 0) {
      throw new Error("Issuer cannot be null or empty");
    }

    if (this.digits < TypeHelpers.getMinDigits(this.type)) {
      throw new Error(`Too few digits, expected at least ${TypeHelpers.getMinDigits(this.type)}`);
    }

    if (this.digits > TypeHelpers.getMaxDigits(this.type)) {
      throw new Error(`Too many digits, expected fewer than ${TypeHelpers.getMaxDigits(this.type)}`);
    }

    if (TypeHelpers.getGenerationMethod(this.type) === GenerationMethod.Time && this.period <= 0) {
      throw new Error("Period cannot be negative or zero");
    }

    SecretUtil.validate(this.secret, this.type);
  }
}