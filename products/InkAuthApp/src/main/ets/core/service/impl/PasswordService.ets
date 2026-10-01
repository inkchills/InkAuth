// PasswordService.ets — SHA-256 password hash via CryptoArchitectureKit

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * 密码服务 - 应用锁定密码（验证哈希）与首次启动状态
 * 注意：密钥本体由 AuthenticatorService 的加密 Preferences 保护，
 * 此处密码仅用于应用解锁门禁，不再声称“加密整个数据库”。
 */
export class PasswordService {
  private static instance: PasswordService;
  private _store: preferences.Preferences | null = null;
  private _initialized: boolean = false;
  private static readonly STORE_NAME: string = 'password_store';
  private static readonly KEY_PASSWORD_HASH: string = 'password_hash';
  private static readonly KEY_HASH_VERSION: string = 'hash_version';
  private static readonly KEY_FIRST_LAUNCH: string = 'first_launch';
  private static readonly KEY_HAS_PASSWORD: string = 'has_password';
  private static readonly HASH_VERSION_SHA256: number = 2;

  private constructor() {}

  public static getInstance(): PasswordService {
    if (!PasswordService.instance) {
      PasswordService.instance = new PasswordService();
    }
    return PasswordService.instance;
  }

  public async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this._initialized) return;
    try {
      const options: preferences.Options = { name: PasswordService.STORE_NAME };
      this._store = preferences.getPreferencesSync(context, options);
      this._initialized = true;
    } catch (err) {
      console.error('初始化密码存储失败:', err);
    }
  }

  public isFirstLaunch(): boolean {
    if (!this._store) return true;
    return this._store.getSync(PasswordService.KEY_FIRST_LAUNCH, true) as boolean;
  }

  public async setFirstLaunchComplete(): Promise<void> {
    if (!this._store) return;
    this._store.putSync(PasswordService.KEY_FIRST_LAUNCH, false);
    await this._store.flush();
  }

  public hasPassword(): boolean {
    if (!this._store) return false;
    return this._store.getSync(PasswordService.KEY_HAS_PASSWORD, false) as boolean;
  }

  public async setPassword(password: string): Promise<void> {
    if (!this._store) return;
    const hash = await this.sha256Hex(password);
    this._store.putSync(PasswordService.KEY_PASSWORD_HASH, hash);
    this._store.putSync(PasswordService.KEY_HASH_VERSION, PasswordService.HASH_VERSION_SHA256);
    this._store.putSync(PasswordService.KEY_HAS_PASSWORD, true);
    await this._store.flush();
  }

  public async verifyPassword(password: string): Promise<boolean> {
    if (!this._store) return false;
    const storedHash = this._store.getSync(PasswordService.KEY_PASSWORD_HASH, '') as string;
    if (!storedHash) return false;

    const version = this._store.getSync(PasswordService.KEY_HASH_VERSION, 1) as number;
    if (version >= PasswordService.HASH_VERSION_SHA256) {
      const hash = await this.sha256Hex(password);
      return hash === storedHash;
    }

    // Migrate legacy simpleHash on successful verify
    if (this.legacySimpleHash(password) === storedHash) {
      await this.setPassword(password);
      return true;
    }
    return false;
  }

  /** Sync wrapper for call sites that cannot await; prefer verifyPassword. */
  public verifyPasswordSync(password: string): boolean {
    if (!this._store) return false;
    const storedHash = this._store.getSync(PasswordService.KEY_PASSWORD_HASH, '') as string;
    if (!storedHash) return false;
    const version = this._store.getSync(PasswordService.KEY_HASH_VERSION, 1) as number;
    if (version < PasswordService.HASH_VERSION_SHA256) {
      return this.legacySimpleHash(password) === storedHash;
    }
    // Sync path cannot compute SHA-256; callers should use async verify.
    return false;
  }

  public async clearPassword(): Promise<void> {
    if (!this._store) return;
    this._store.putSync(PasswordService.KEY_PASSWORD_HASH, '');
    this._store.putSync(PasswordService.KEY_HAS_PASSWORD, false);
    await this._store.flush();
  }

  private async sha256Hex(input: string): Promise<string> {
    const md = cryptoFramework.createMd('SHA256');
    const bytes = this.stringToUtf8(input);
    await md.update({ data: bytes });
    const digest = await md.digest();
    return this.bytesToHex(digest.data);
  }

  private legacySimpleHash(input: string): string {
    let hash = 0;
    for (let i = 0; i < input.length; i++) {
      const char = input.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    let hashStr = hash.toString(16);
    for (let round = 0; round < 1000; round++) {
      let h = 0;
      for (let i = 0; i < hashStr.length; i++) {
        const c = hashStr.charCodeAt(i);
        h = ((h << 5) - h) + c;
        h = h & h;
      }
      hashStr = h.toString(16);
    }
    return hashStr;
  }

  private stringToUtf8(value: string): Uint8Array {
    const buffer = new ArrayBuffer(value.length * 3);
    const view = new Uint8Array(buffer);
    let offset = 0;
    for (let i = 0; i < value.length; i++) {
      let code = value.charCodeAt(i);
      if (code < 0x80) {
        view[offset++] = code;
      } else if (code < 0x800) {
        view[offset++] = 0xC0 | (code >> 6);
        view[offset++] = 0x80 | (code & 0x3F);
      } else {
        view[offset++] = 0xE0 | (code >> 12);
        view[offset++] = 0x80 | ((code >> 6) & 0x3F);
        view[offset++] = 0x80 | (code & 0x3F);
      }
    }
    return view.slice(0, offset);
  }

  private bytesToHex(bytes: Uint8Array): string {
    let out = '';
    for (let i = 0; i < bytes.length; i++) {
      const h = bytes[i].toString(16);
      out += h.length === 1 ? `0${h}` : h;
    }
    return out;
  }
}
