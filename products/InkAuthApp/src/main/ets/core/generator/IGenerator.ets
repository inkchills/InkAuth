// IGenerator.ts

/**
 * OTP生成器接口
 */
export interface IGenerator {
  /**
   * 计算OTP代码
   * @param counter 计数器值
   * @returns OTP代码
   */
  compute(counter: number): Promise<string>;
}
