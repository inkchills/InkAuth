import { Authenticator } from '../../../core/entity/Authenticator';
import { ThemeColors } from '../../../core/util/ThemeManager';
import { pasteboard } from '@kit.BasicServicesKit';

@Component
export struct QrCodeSheet {
  @Prop visible: boolean;
  @Prop authenticator: Authenticator | null;
  @Prop colors: ThemeColors;
  onClose: () => void = () => {};

  private async copyUri(): Promise<void> {
    if (!this.authenticator) {
      return;
    }

    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.authenticator.getUri());
      await pasteboard.getSystemPasteboard().setData(pasteData);
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: 'URI 已复制', duration: 1500 });
    } catch (error) {
      console.error('复制 URI 失败:', error);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '复制 URI 失败', duration: 1500 });
      } catch (_e) {}
    }
  }

  build() {
    if (this.visible && this.authenticator) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => this.onClose())

        // 内容框
        Column() {
          Text(this.authenticator.issuer || 'Unknown')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors.text)
            .margin({ top: 8, bottom: 24 })
            .textAlign(TextAlign.Center)

          Row() {
            QRCode(this.authenticator.getUri())
              .width(200)
              .height(200)
              .color('#000000') // Force black QR code
              .backgroundColor(Color.White) // Force white background
          }
          .padding(16)
          .backgroundColor('#FFFFFF') // Force white background container
          .borderRadius(12)

          Text('扫描二维码以导入认证器')
            .fontSize(14)
            .fontColor(this.colors.textSecondary)
            .margin({ top: 24 })
            .textAlign(TextAlign.Center)

          Row({ space: 12 }) {
            Button('复制 URI')
              .height(40)
              .backgroundColor(this.colors.surface)
              .fontColor(this.colors.text)
              .border({ width: 1, color: this.colors.border, radius: 20 })
              .onClick((): void => { this.copyUri(); })

            Button('完成')
              .height(40)
              .backgroundColor(this.colors.primary)
              .fontColor(this.colors.onPrimary)
              .borderRadius(20)
              .onClick((): void => { this.onClose(); })
          }
          .margin({ top: 20 })
          .justifyContent(FlexAlign.Center)
        }
        .width('85%')
        .padding(24)
        .backgroundColor(this.colors.surface)
        .borderRadius(24)
        .shadow({ radius: 20, color: 'rgba(0,0,0,0.2)' })
        .onClick(() => {}) // 阻止点击穿透
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(100)
    }
  }
}
