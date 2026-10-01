// QrScannerOverlay.ets - 二维码扫描覆盖层（集成 HarmonyOS ScanKit）

import { ThemeColors } from '../../../core/util/ThemeManager';
import { common } from '@kit.AbilityKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { AuthenticatorService } from '../../../core/service/impl/AuthenticatorService';
import { UriParser } from '../../../core/UriParser';
import { IconResolver } from '../../../core/util/IconResolver';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'QrScanner';

@Component
export struct QrScannerOverlay {
  @Prop visible: boolean = false;
  @Prop colors: ThemeColors;
  onClose: () => void = () => {};
  onScanResult: (count: number) => void = (_count: number) => {};
  private authenticatorService: AuthenticatorService = AuthenticatorService.getInstance();
  private iconResolver: IconResolver = new IconResolver();

  @State private scanStatus: string = '点击下方按钮开始扫描';
  @State private isScanning: boolean = false;

  // 使用 ScanKit 启动相机扫描
  async startCameraScan(): Promise<void> {
    this.isScanning = true;
    this.scanStatus = '正在启动扫描...';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;

      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      };

      hilog.info(LOG_DOMAIN, LOG_TAG, 'startCameraScan: launching ScanKit...');
      const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(context, options);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'startCameraScan: result received, originalValue=%{public}s, hasScanCodeRect=%{public}s',
        result ? (result.originalValue || '(empty)') : '(null)',
        result && result.scanCodeRect !== undefined ? 'true' : 'false');

      if (result && result.originalValue) {
        const scannedText = result.originalValue;
        hilog.info(LOG_DOMAIN, LOG_TAG, 'startCameraScan: scanned text = %{public}s', scannedText);
        await this.handleScannedText(scannedText);
      } else {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'startCameraScan: no originalValue, treating as cancelled');
        this.scanStatus = '扫描已取消';
      }
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'startCameraScan error: %{public}s', errMsg);
      if (errMsg.includes('cancel') || errMsg.includes('1000500001')) {
        this.scanStatus = '扫描已取消';
      } else {
        this.scanStatus = '扫描失败: ' + errMsg;
      }
    } finally {
      this.isScanning = false;
    }
  }

  // ScanKit 扫描界面已启用相册入口，这里直接复用同一条导入路径。
  async selectImageAndDecode(): Promise<void> {
    this.scanStatus = '请在扫描界面使用相册入口选择图片';
    await this.startCameraScan();
  }

  // 处理扫描到的文本
  private async handleScannedText(text: string): Promise<void> {
    const value = text.trim();
    hilog.info(LOG_DOMAIN, LOG_TAG, 'handleScannedText: value=%{public}s', value);

    if (value.startsWith('otpauth://') || value.startsWith('motp://')) {
      try {
        const parsed = UriParser.parseStandardUri(value, this.iconResolver);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'handleScannedText: parsed OTP URI, issuer=%{public}s', parsed.authenticator.issuer || '');
        await this.authenticatorService.create(parsed.authenticator);
        this.scanStatus = '添加成功: ' + (parsed.authenticator.issuer || '认证器');
        this.onScanResult(1);
        return;
      } catch (e) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'handleScannedText: URI parse failed: %{public}s', String(e));
        this.scanStatus = 'URI 解析失败';
        return;
      }
    }

    if (value.startsWith('otpauth-migration://')) {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'handleScannedText: Google migration URI detected');
      try {
        const authenticators = UriParser.parseOtpAuthMigrationUri(value, this.iconResolver);
        let addedCount = 0;
        for (const authenticator of authenticators) {
          await this.authenticatorService.create(authenticator);
          addedCount++;
        }
        this.scanStatus = `Google Authenticator 导入成功: ${addedCount} 个认证器`;
        this.onScanResult(addedCount);
      } catch (error) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'handleScannedText: migration parse failed: %{public}s', String(error));
        this.scanStatus = 'Google Authenticator 迁移二维码解析失败';
      }
      return;
    }

    hilog.warn(LOG_DOMAIN, LOG_TAG, 'handleScannedText: not a valid OTP QR code');
    this.scanStatus = '不是有效的 OTP 二维码';
  }

  build() {
    if (this.visible) {
      Stack() {
        // 半透明背景
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.3)')
          .onClick(() => this.onClose())

        Column({ space: 16 }) {
          // 标题栏
          Row() {
            Text('扫描二维码')
              .fontSize(18)
              .fontWeight(700)
              .fontColor(this.colors.text)
            Blank().flexGrow(1)
            Image($r('app.media.baseline_close_24'))
              .width(24).height(24)
              .fillColor(this.colors.onBackground)
              .onClick(() => this.onClose())
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 20 })

          // 图标区域
          Column({ space: 12 }) {

            Text('将 OTP 二维码对准相机\n或从图片中识别')
              .fontSize(14)
              .fontColor(this.colors.textSecondary)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ top: 24, bottom: 16 })
          .alignItems(HorizontalAlign.Center)

          // 状态文本
          Text(this.scanStatus)
            .fontSize(13)
            .fontColor(this.isScanning ? this.colors.primary : this.colors.textSecondary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ left: 20, right: 20 })

          // 操作按钮
          Column({ space: 12 }) {
            Button(this.isScanning ? '扫描中...' : '启动相机扫描')
              .width('90%')
              .height(48)
              .backgroundColor(this.colors.primary)
              .fontColor(this.colors.onPrimary)
              .borderRadius(24)
              .enabled(!this.isScanning)
              .onClick((): void => {
                this.startCameraScan();
              })

            Button('从相册导入')
              .width('90%')
              .height(48)
              .backgroundColor('transparent')
              .fontColor(this.colors.onBackground)
              .border({ width: 1, color: this.colors.border, radius: 24 })
              .enabled(!this.isScanning)
              .onClick((): void => {
                this.selectImageAndDecode();
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ bottom: 24 })
        }
        .width('100%')
        .backgroundColor(this.colors.background)
        .borderRadius({ topLeft: 20, topRight: 20 })
        .position({ x: 0, y: '35%' })
      }
      .width('100%')
      .height('100%')
      .zIndex(9500)
    }
  }
}
