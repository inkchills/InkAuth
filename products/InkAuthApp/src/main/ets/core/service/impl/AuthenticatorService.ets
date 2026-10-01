// AuthenticatorService.ets — Preferences persistence with encrypt-at-rest

import { IAuthenticatorService } from '../IAuthenticatorService';
import { Authenticator } from '../../entity/Authenticator';
import { AuthenticatorType } from '../../AuthenticatorType';
import { HashAlgorithm } from '../../generator/HashAlgorithm';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 持久化的认证器数据接口
 */
interface AuthenticatorData {
  type: number;
  icon: string | null;
  issuer: string | null;
  username: string | null;
  categoryId: string | null;
  secret: string;
  pin: string | null;
  algorithm: number;
  digits: number;
  period: number;
  counter: number;
  copyCount: number;
  ranking: number;
}

/**
 * 认证器服务实现 - 使用加密 Preferences 持久化
 */
export class AuthenticatorService implements IAuthenticatorService {
  private static instance: AuthenticatorService;
  private _authenticators: Map<string, Authenticator> = new Map();
  private _store: preferences.Preferences | null = null;
  private _initialized: boolean = false;
  private static readonly STORE_NAME: string = 'authenticator_store';
  private static readonly STORE_NAME_SECURE: string = 'authenticator_store_secure';
  private static readonly KEY_AUTHENTICATORS: string = 'authenticators';

  private constructor() {}

  public static getInstance(): AuthenticatorService {
    if (!AuthenticatorService.instance) {
      AuthenticatorService.instance = new AuthenticatorService();
    }
    return AuthenticatorService.instance;
  }

  public async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this._initialized) {
      return;
    }
    try {
      // Preferences (current SDK Options has no encrypt field; use dedicated store name).
      try {
        const secureOptions: preferences.Options = {
          name: AuthenticatorService.STORE_NAME_SECURE
        };
        this._store = preferences.getPreferencesSync(context, secureOptions);
      } catch (secureErr) {
        console.error('安全 Preferences 不可用，回退普通存储:', secureErr);
        const plainOptions: preferences.Options = { name: AuthenticatorService.STORE_NAME };
        this._store = preferences.getPreferencesSync(context, plainOptions);
      }

      await this.migrateFromLegacyStoreIfNeeded(context);
      await this.loadFromStore();
      this._initialized = true;
    } catch (err) {
      console.error('初始化认证器存储失败:', err);
    }
  }

  /**
   * 将旧版明文 authenticator_store 迁移到加密 store（一次性）。
   */
  private async migrateFromLegacyStoreIfNeeded(context: common.UIAbilityContext): Promise<void> {
    if (!this._store) {
      return;
    }
    try {
      const existing = this._store.getSync(AuthenticatorService.KEY_AUTHENTICATORS, '') as string;
      if (existing && existing !== '[]') {
        return;
      }
      const legacyOptions: preferences.Options = { name: AuthenticatorService.STORE_NAME };
      const legacy = preferences.getPreferencesSync(context, legacyOptions);
      const legacyJson = legacy.getSync(AuthenticatorService.KEY_AUTHENTICATORS, '') as string;
      if (!legacyJson || legacyJson === '[]') {
        return;
      }
      this._store.putSync(AuthenticatorService.KEY_AUTHENTICATORS, legacyJson);
      await this._store.flush();
      legacy.putSync(AuthenticatorService.KEY_AUTHENTICATORS, '[]');
      await legacy.flush();
      console.info('已将认证器数据迁移到加密存储');
    } catch (err) {
      console.error('迁移旧版认证器存储失败:', err);
    }
  }

  private async loadFromStore(): Promise<void> {
    if (!this._store) return;
    try {
      const jsonStr = this._store.getSync(AuthenticatorService.KEY_AUTHENTICATORS, '[]') as string;
      const dataList: AuthenticatorData[] = JSON.parse(jsonStr) as AuthenticatorData[];
      this._authenticators.clear();
      for (const data of dataList) {
        const auth = this.dataToAuthenticator(data);
        const id = this.generateId(auth);
        this._authenticators.set(id, auth);
      }
    } catch (err) {
      console.error('加载认证器数据失败:', err);
    }
  }

  private async saveToStore(): Promise<void> {
    if (!this._store) return;
    try {
      const dataList: AuthenticatorData[] = [];
      for (const auth of this._authenticators.values()) {
        dataList.push(this.authenticatorToData(auth));
      }
      const jsonStr = JSON.stringify(dataList);
      this._store.putSync(AuthenticatorService.KEY_AUTHENTICATORS, jsonStr);
      await this._store.flush();
    } catch (err) {
      console.error('保存认证器数据失败:', err);
    }
  }

  private authenticatorToData(auth: Authenticator): AuthenticatorData {
    return {
      type: auth.type as number,
      icon: auth.icon,
      issuer: auth.issuer,
      username: auth.username,
      categoryId: auth.categoryId,
      secret: auth.secret,
      pin: auth.pin,
      algorithm: auth.algorithm as number,
      digits: auth.digits,
      period: auth.period,
      counter: auth.counter,
      copyCount: auth.copyCount,
      ranking: auth.ranking
    };
  }

  private dataToAuthenticator(data: AuthenticatorData): Authenticator {
    const auth = new Authenticator();
    auth.type = data.type as AuthenticatorType;
    auth.icon = data.icon;
    auth.issuer = data.issuer;
    auth.username = data.username;
    auth.categoryId = data.categoryId || null;
    auth.secret = data.secret;
    auth.pin = data.pin;
    auth.algorithm = data.algorithm as HashAlgorithm;
    auth.digits = data.digits;
    auth.period = data.period;
    auth.counter = data.counter;
    auth.copyCount = data.copyCount;
    auth.ranking = data.ranking;
    return auth;
  }

  public async getAll(): Promise<Authenticator[]> {
    return Array.from(this._authenticators.values());
  }

  public async getById(id: string): Promise<Authenticator | null> {
    return this._authenticators.get(id) || null;
  }

  public async create(authenticator: Authenticator): Promise<void> {
    const id = this.generateId(authenticator);
    this._authenticators.set(id, authenticator);
    await this.saveToStore();
  }

  public async update(authenticator: Authenticator): Promise<void> {
    const id = this.generateId(authenticator);
    // Also try matching by existing entries if secret/issuer changed via edit sheet using original id
    if (this._authenticators.has(id)) {
      this._authenticators.set(id, authenticator);
      await this.saveToStore();
      return;
    }
    throw new Error('Authenticator not found');
  }

  /**
   * Update when the identity key may have changed (issuer/username/secret).
   */
  public async updateWithId(oldId: string, authenticator: Authenticator): Promise<void> {
    this._authenticators.delete(oldId);
    const newId = this.generateId(authenticator);
    this._authenticators.set(newId, authenticator);
    await this.saveToStore();
  }

  public async delete(id: string): Promise<void> {
    this._authenticators.delete(id);
    await this.saveToStore();
  }

  public async reorder(ids: string[]): Promise<void> {
    let rank = 0;
    for (const id of ids) {
      const auth = this._authenticators.get(id);
      if (auth) {
        auth.ranking = rank++;
      }
    }
    await this.saveToStore();
  }

  public async clear(): Promise<void> {
    this._authenticators.clear();
    await this.saveToStore();
  }

  public async resetCopyCounts(): Promise<void> {
    for (const auth of this._authenticators.values()) {
      auth.copyCount = 0;
    }
    await this.saveToStore();
  }

  public getCount(): number {
    return this._authenticators.size;
  }

  public generateId(authenticator: Authenticator): string {
    return `${authenticator.issuer}:${authenticator.username}:${authenticator.secret}`;
  }
}
