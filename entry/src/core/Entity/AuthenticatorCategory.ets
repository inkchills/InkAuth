// Copyright (C) 2022 jmh
// SPDX-License-Identifier: GPL-3.0-only

/**
 * 认证器类别实体类
 * 对应数据库表: authenticatorcategory
 */
export class AuthenticatorCategory {
  // 表名常量
  public static readonly TABLE_NAME: string = 'authenticatorcategory';

  // 列名常量
  public static readonly COLUMN_CATEGORY_ID: string = 'categoryId';
  public static readonly COLUMN_AUTHENTICATOR_SECRET: string = 'authenticatorSecret';
  public static readonly COLUMN_RANKING: string = 'ranking';

  /**
   * 类别ID
   * 对应数据库列: categoryId (索引字段)
   */
  categoryId: string = '';

  /**
   * 认证器密钥
   * 对应数据库列: authenticatorSecret (索引字段)
   */
  authenticatorSecret: string = '';

  /**
   * 排名
   * 对应数据库列: ranking
   */
  ranking: number = 0;

  /**
   * 默认构造函数
   */
  constructor() {
    this.ranking = 0;
  }

  /**
   * 带参数的构造函数
   * @param authenticatorSecret 认证器密钥
   * @param categoryId 类别ID
   */
  constructorWithParams(authenticatorSecret: string, categoryId: string): void {
    this.authenticatorSecret = authenticatorSecret;
    this.categoryId = categoryId;
    this.ranking = 0;
  }
}