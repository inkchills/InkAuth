// Authenticator.ts

import { IGenerator } from '../generator/IGenerator';
import { HashAlgorithm } from '../generator/HashAlgorithm';
import { AuthenticatorType, AuthenticatorTypeSpecification, GenerationMethod } from '../AuthenticatorType';
import { Totp } from '../generator/Totp';
import { Hotp } from '../generator/Hotp';
import { MobileOtp } from '../generator/MobileOtp';
import { SteamOtp } from '../generator/SteamOtp';
import { YandexOtp } from '../generator/YandexOtp';
import { SecretUtil } from '../util/SecretUtil';

/**
 * 认证器类
 */
export class Authenticator {
    public static readonly IssuerMaxLength: number = 32;
    public static readonly UsernameMaxLength: number = 40;

    public static readonly DefaultAlgorithm: HashAlgorithm = HashAlgorithm.Sha1;

    private _generator: IGenerator | null = null;
    private _lastCounter: number = 0;
    private _code: string | null = null;

    public type: AuthenticatorType;
    public icon: string | null = null;
    public issuer: string | null = null;
    public username: string | null = null;
    public categoryId: string | null = null;
    public secret: string;
    public pin: string | null = null;
    public algorithm: HashAlgorithm;
    public digits: number;
    public period: number;
    public counter: number = 0;
    public copyCount: number = 0;
    public ranking: number = 0;

    /**
     * 构造函数
     */
    constructor() {
        this._code = null;
        this._generator = null;
        this._lastCounter = 0;

        this.algorithm = Authenticator.DefaultAlgorithm;
        this.type = AuthenticatorType.Totp;
        this.digits = AuthenticatorTypeSpecification.getMinDigits(this.type);
        this.period = AuthenticatorTypeSpecification.getDefaultPeriod(this.type);
        this.secret = '';
    }

    /**
     * 获取OTP代码
     * @param counter 计数器值
     * @returns OTP代码
     */
    public async getCode(counter: number): Promise<string> {
        if (!this._generator) {
            switch (this.type) {
                case AuthenticatorType.Totp:
                    this._generator = new Totp(this.secret, this.period, this.algorithm, this.digits);
                    break;
                case AuthenticatorType.Hotp:
                    this._generator = new Hotp(this.secret, this.algorithm, this.digits);
                    break;
                case AuthenticatorType.MobileOtp:
                    this._generator = new MobileOtp(this.secret, this.pin || '');
                    break;
                case AuthenticatorType.SteamOtp:
                    this._generator = new SteamOtp(this.secret);
                    break;
                case AuthenticatorType.YandexOtp:
                    this._generator = new YandexOtp(this.secret, this.pin || '');
                    break;
                default:
                    throw new Error('Unknown authenticator type');
            }
        }

        const generationMethod = AuthenticatorTypeSpecification.getGenerationMethod(this.type);
        switch (generationMethod) {
            case GenerationMethod.Time:
                if (this._code !== null && this._lastCounter === counter) {
                    return this._code!;
                }
                this._code = await this._generator!.compute(counter);
                this._lastCounter = counter;
                break;

            case GenerationMethod.Counter:
                if (this._code !== null && this._lastCounter === this.counter) {
                    return this._code!;
                }
                this._code = await this._generator!.compute(this.counter);
                this._lastCounter = this.counter;
                break;
        }

        return this._code!;
    }

    /**
     * 获取默认OTP代码
     * @returns OTP代码
     */
    public async getCodeDefault(): Promise<string> {
        let counter: number;

        const generationMethod = AuthenticatorTypeSpecification.getGenerationMethod(this.type);
        switch (generationMethod) {
            case GenerationMethod.Time:
                const now = Math.floor(Date.now() / 1000);
                counter = now - (now % this.period);
                break;

            case GenerationMethod.Counter:
                counter = this.counter;
                break;

            default:
                throw new Error('Unknown generation method');
        }

        return this.getCode(counter);
    }

    /**
     * 获取Mobile OTP URI
     * @returns URI字符串
     */
    private getMotpUri(): string {
        let builder = 'motp://';
        builder += this.issuer;
        builder += ':';
        builder += this.username;
        builder += '?secret=';
        builder += this.secret;

        return builder;
    }

    /**
     * 获取OTP Auth URI
     * @returns URI字符串
     */
    private getOtpAuthUri(): string {
        let type: string;
        switch (this.type) {
            case AuthenticatorType.Hotp:
                type = 'hotp';
                break;
            case AuthenticatorType.Totp:
                type = 'totp';
                break;
            case AuthenticatorType.SteamOtp:
                type = 'totp';
                break;
            case AuthenticatorType.YandexOtp:
                type = 'yaotp';
                break;
            default:
                throw new Error('Unsupported authenticator type');
        }

        const issuerUsername = this.username ? `${this.issuer}:${this.username}` : this.issuer;
        const encodedIssuerUsername = encodeURIComponent(issuerUsername!);
        const encodedIssuer = encodeURIComponent(this.issuer!);

        let uri = `otpauth://${type}/${encodedIssuerUsername}?secret=${this.secret}&issuer=${encodedIssuer}`;

        if (this.algorithm !== Authenticator.DefaultAlgorithm) {
            let algorithmName: string;
            switch (this.algorithm) {
                case HashAlgorithm.Sha256:
                    algorithmName = 'SHA256';
                    break;
                case HashAlgorithm.Sha512:
                    algorithmName = 'SHA512';
                    break;
                default:
                    throw new Error('Unsupported algorithm');
            }

            uri += `&algorithm=${algorithmName}`;
        }

        if (this.digits !== AuthenticatorTypeSpecification.getMinDigits(this.type)) {
            uri += `&digits=${this.digits}`;
        }

        switch (this.type) {
            case AuthenticatorType.Totp:
                if (this.period !== AuthenticatorTypeSpecification.getDefaultPeriod(this.type)) {
                    uri += `&period=${this.period}`;
                }
                break;

            case AuthenticatorType.Hotp:
                uri += `&counter=${this.counter}`;
                break;

            case AuthenticatorType.SteamOtp:
                if (this.issuer !== 'Steam') {
                    uri += '&steam';
                }
                break;

            case AuthenticatorType.YandexOtp:
                if (this.pin) {
                    uri += `&pin_length=${this.pin.length}`;
                }
                break;
        }

        return uri;
    }

    /**
     * 获取URI
     * @returns URI字符串
     */
    public getUri(): string {
        return this.type === AuthenticatorType.MobileOtp ? this.getMotpUri() : this.getOtpAuthUri();
    }

    /**
     * 验证认证器
     */
    public validate(): void {
        if (!this.issuer) {
            throw new Error('Issuer cannot be null or empty');
        }

        if (this.digits < AuthenticatorTypeSpecification.getMinDigits(this.type)) {
            throw new Error(`Too few digits, expected at least ${AuthenticatorTypeSpecification.getMinDigits(this.type)}`);
        }

        if (this.digits > AuthenticatorTypeSpecification.getMaxDigits(this.type)) {
            throw new Error(`Too many digits, expected fewer than ${AuthenticatorTypeSpecification.getMaxDigits(this.type)}`);
        }

        if (AuthenticatorTypeSpecification.getGenerationMethod(this.type) === GenerationMethod.Time && this.period <= 0) {
            throw new Error('Period cannot be negative or zero');
        }

        SecretUtil.validate(this.secret, this.type);
    }
}
