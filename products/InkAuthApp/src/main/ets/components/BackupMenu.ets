// BackupMenu.ets

import promptAction from '@ohos.promptAction';
import { ThemeColors } from '../core/util/ThemeManager';

@Component
export struct BackupMenu {
  @Prop visible: boolean;
  @Prop colors: ThemeColors;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;
  onEncryptedBackup: () => void = () => {};
  onHtmlBackup: () => void = () => {};
  onUriBackup: () => void = () => {};
  onRestoreBackup: () => void = () => {};
  onClose: () => void = () => {};

  build() {
    if (this.visible) {
      Stack() {
        // 背景遮罩
        Column() {
          Text('')
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => this.onClose())
        }
        .width('100%')
        .height('100%')

        // 菜单内容
        Column() {
          // 顶部指示器
          Row() {
            Text('')
              .width(40)
              .height(4)
              .backgroundColor(this.colors.divider)
              .borderRadius(2)
          }
          .width('100%')
          .height(20)
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)

          // 标题和关闭按钮
          Row() {
            Text('备份')
              .fontSize(18)
              .fontWeight(700)
              .fontColor(this.colors.text)
              .flexGrow(1)
            Image($r('app.media.baseline_close_24'))
              .width(24).height(24)
              .fillColor(this.colors.onBackground)
              .onClick(() => this.onClose())
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)

          Column() {
            // 加密备份
            Row() {
              Image($r('app.media.baseline_lock_24'))
                .width(24).height(24)
                .fillColor(this.colors.textSecondary)
                .margin({ right: 12 })
              Column() {
                Text('保存为加密文件 (推荐)')
                  .fontSize(16)
                  .fontWeight(500)
                  .fontColor(this.colors.text)
                  .textAlign(TextAlign.Start)
                Text('使用强加密保存所有验证器和分类，可用于恢复或迁移到 Android 版。')
                  .fontSize(14)
                  .fontColor(this.colors.textSecondary)
                  .textAlign(TextAlign.Start)
              }
              .flexGrow(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onEncryptedBackup())

            // HTML备份
            Row() {
              Image($r('app.media.baseline_html_24'))
                .width(24).height(24)
                .fillColor(this.colors.textSecondary)
                .margin({ right: 12 })
              Column() {
                Text('保存为 HTML 文件')
                  .fontSize(16)
                  .fontWeight(500)
                  .fontColor(this.colors.text)
                  .margin({ bottom: 4 })
                Text('以二维码形式保存到未加密的HTML文档中。')
                  .fontSize(14)
                  .fontColor(this.colors.textSecondary)
                  .textAlign(TextAlign.Start)
              }
              .flexGrow(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onHtmlBackup())

            // URI列表备份
            Row() {
              Image($r('app.media.baseline_list_24'))
                .width(24).height(24)
                .margin({ right: 12 })
              Column() {
                Text('备份至 URI 列表文件')
                  .fontSize(16)
                  .fontWeight(500)
                  .margin({ bottom: 4 })
                Text('保存到未加密纯文本的URI列表文件，与其他应用兼容。')
                  .fontSize(14)
                  .fontColor('#666666')
                  .textAlign(TextAlign.Start)
              }
              .flexGrow(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onUriBackup())

            // 恢复备份
            Row() {
              Image($r('app.media.baseline_restore_24'))
                .width(24).height(24)
                .margin({ right: 12 })
              Column() {
                Text('从备份文件恢复')
                  .fontSize(16)
                  .fontWeight(500)
                  .textAlign(TextAlign.Start)
                Text('从之前创建的备份文件中恢复验证器、分类和图标设置。')
                  .fontSize(14)
                  .fontColor('#666666')
                  .textAlign(TextAlign.Start)
              }
              .flexGrow(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 32 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onRestoreBackup())
          }
          .flexGrow(1)
        }
        .width('100%')
        .backgroundColor(this.colors.surface)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .padding({ bottom: 12 + px2vp(this.insetBottomPx) })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Bottom)
    }
  }
}
