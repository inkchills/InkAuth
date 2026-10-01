// 导入必要的ArkTS模块
import { util } from '@kit.ArkTS';
// 导入加解密框架，虽然具体API需查阅其他文档，但这是标准模块
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * 哈希工具类
 * 提供 SHA1 和 MD5 哈希计算功能
 */
export class HashUtil {

  /**
   * 计算字符串的 SHA1 哈希值
   * @param input - 待计算的输入字符串
   * @returns 返回一个 Promise，解析为小写的十六进制哈希字符串
   * @throws 在哈希计算失败时抛出错误
   */
  public static async sha1(input: string): Promise<string> {
    return HashUtil.hash(input, 'SHA1');
  }

  /**
   * 计算字符串的 MD5 哈希值
   * @param input - 待计算的输入字符串
   * @returns 返回一个 Promise，解析为小写的十六进制哈希字符串
   * @throws 在哈希计算失败时抛出错误
   */
  public static async md5(input: string): Promise<string> {
    return HashUtil.hash(input, 'MD5');
  }

  /**
   * 通用的哈希计算内部方法
   * @param input - 输入字符串
   * @param algorithm - 算法标识，如 'SHA1', 'MD5'
   * @returns 返回一个 Promise，解析为小写的十六进制哈希字符串
   * @private
   */
  private static async hash(input: string, algorithm: string): Promise<string> {
    // 参数校验
    if (input === null || input === undefined) {
      // 与C#的 string.IsNullOrEmpty 行为保持一致
      throw new Error('Input string cannot be null or undefined');
    }

    try {
      // 1. 使用 util.TextEncoder 将字符串转换为 UTF-8 字节数组 (Uint8Array)
      // 这是对 util 文档中 TextEncoder 的正确应用
      const textEncoder = new util.TextEncoder();
      const data: Uint8Array = textEncoder.encodeInto(input);

      // 2. 创建指定算法的消息摘要计算器
      // 这里假设 cryptoFramework.createMd 是创建摘要生成器的正确API
      const md: cryptoFramework.Md = cryptoFramework.createMd(algorithm);

      // 3. 更新数据（传入字节数组）
      await md.update({ data: data });

      // 4. 计算并获取摘要结果
      const mdOutput: cryptoFramework.DataBlob = await md.digest();

      // 5. 将结果字节数组(Uint8Array)转换为小写的十六进制字符串
      // mdOutput.data 应是一个 Uint8Array
      const hashHex = HashUtil.bytesToHex(mdOutput.data).toLowerCase();

      return hashHex;

    } catch (error) {
      // 将捕获的错误重新抛出，提供更清晰的上下文信息
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to compute ${algorithm} hash: ${errorMessage}`);
    }
  }

  /**
   * 辅助方法：将 Uint8Array 字节数组转换为十六进制字符串
   * @param bytes - 字节数组
   * @returns 十六进制字符串
   * @private
   */
  private static bytesToHex(bytes: Uint8Array): string {
    // 使用 Array.from 和 map 高效地将每个字节转换为两位十六进制
    return Array.from(bytes)
      .map(byte => byte.toString(16).padStart(2, '0'))
      .join('');
  }
}