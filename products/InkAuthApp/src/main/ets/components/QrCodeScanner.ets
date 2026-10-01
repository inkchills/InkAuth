// QrCodeScanner.ets

import { AuthenticatorService } from '../core/service/impl/AuthenticatorService';
import { UriParser } from '../core/UriParser';
import { IconResolver } from '../core/util/IconResolver';

export class QrCodeScanner {
  private authenticatorService: AuthenticatorService = AuthenticatorService.getInstance();
  private iconResolver: IconResolver = new IconResolver();

  /**
   * 处理扫描到的文本
   */
  async handleScannedText(text: string): Promise<void> {
    try {
      const value = text.trim();
      if (value.startsWith('otpauth-migration://')) {
        const authenticators = UriParser.parseOtpAuthMigrationUri(value, this.iconResolver);
        for (const authenticator of authenticators) {
          await this.authenticatorService.create(authenticator);
        }
        return;
      }

      if (!value.startsWith('otpauth://') && !value.startsWith('motp://')) {
        throw new Error('不是有效的OTP二维码');
      }

      const parsed = UriParser.parseStandardUri(value, this.iconResolver);
      await this.authenticatorService.create(parsed.authenticator);
    } catch (error) {
      console.error('处理扫码结果失败:', error);
      throw error;
    }
  }

  /**
   * 解析二维码扫描结果
   */
  async parseQrCodeScanResult(uri: string): Promise<void> {
    if (uri.startsWith('otpauth-migration')) {
      const authenticators = UriParser.parseOtpAuthMigrationUri(uri, this.iconResolver);
      for (const authenticator of authenticators) {
        await this.authenticatorService.create(authenticator);
      }
    } else if (uri.startsWith('otpauth') || uri.startsWith('motp')) {
      await this.onUriScan(uri);
    } else {
      throw new Error('二维码格式错误');
    }
  }

  private async onUriScan(uri: string): Promise<void> {
    try {
      const result = UriParser.parseStandardUri(uri, this.iconResolver);
      await this.authenticatorService.create(result.authenticator);
    } catch (error) {
      console.error('解析URI失败:', error);
      throw error;
    }
  }
}
