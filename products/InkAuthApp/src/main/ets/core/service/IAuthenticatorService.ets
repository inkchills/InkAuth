// IAuthenticatorService.ts

import { Authenticator } from '../entity/Authenticator';

/**
 * 认证器服务接口
 */
export interface IAuthenticatorService {
  /**
   * 获取所有认证器
   * @returns 认证器列表
   */
  getAll(): Promise<Authenticator[]>;

  /**
   * 根据ID获取认证器
   * @param id 认证器ID
   * @returns 认证器
   */
  getById(id: string): Promise<Authenticator | null>;

  /**
   * 创建认证器
   * @param authenticator 认证器
   */
  create(authenticator: Authenticator): Promise<void>;

  /**
   * 更新认证器
   * @param authenticator 认证器
   */
  update(authenticator: Authenticator): Promise<void>;

  /**
   * 删除认证器
   * @param id 认证器ID
   */
  delete(id: string): Promise<void>;

  /**
   * 重排序认证器
   * @param ids 认证器ID列表
   */
  reorder(ids: string[]): Promise<void>;
}
