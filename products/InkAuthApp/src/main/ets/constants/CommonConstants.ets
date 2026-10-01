// CommonConstants.ets

/**
 * 通用常量
 */
export class CommonConstants {
  /**
   * 应用名称
   */
  public static readonly APP_NAME: string = 'InkAuth';

  /**
   * 默认主题模式
   */
  public static readonly DEFAULT_THEME_MODE: string = 'light';

  /**
   * 默认周期（秒）
   */
  public static readonly DEFAULT_PERIOD: number = 30;

  /**
   * 默认位数
   */
  public static readonly DEFAULT_DIGITS: number = 6;

  /**
   * 默认算法
   */
  public static readonly DEFAULT_ALGORITHM: number = 0;

  /**
   * 默认类型
   */
  public static readonly DEFAULT_TYPE: number = 0;

  /**
   * 备份提醒阈值（分钟）
   */
  public static readonly BACKUP_REMINDER_THRESHOLD_MINUTES: number = 120;

  /**
   * 最大issuer长度
   */
  public static readonly ISSUER_MAX_LENGTH: number = 32;

  /**
   * 最大username长度
   */
  public static readonly USERNAME_MAX_LENGTH: number = 40;
}
