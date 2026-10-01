// EditMenu.ets

import { Authenticator } from '../core/entity/Authenticator';
import { ThemeColors } from '../core/util/ThemeManager';

@Component
export struct EditMenu {
  @Prop visible: boolean;
  @Prop authenticator: Authenticator | null = null;
  @Prop colors: ThemeColors;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;
  onEditDetails: (auth: Authenticator | null) => void = () => {};
  onChangeIcon: () => void = () => {};
  onAssignCategory: () => void = () => {};
  onShowQrCode: () => void = () => {};
  onDelete: () => void = () => {};
  onCancel: () => void = () => {};

  build() {
    if (this.visible) {
      Stack() {
        // 背景遮罩
        Column() {
          Text('')
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => this.onCancel())
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })

        // 菜单内容
        Column() {
          // 顶部指示器
          Row() {
            Text('')
              .width(40)
              .height(5)
              .backgroundColor(this.colors.divider)
              .borderRadius(3)
          }
          .width('100%')
          .height(32)
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)

          // 标题
          Text('编辑')
            .fontSize(18)
            .fontWeight(700)
            .fontColor(this.colors.text)
            .margin({ bottom: 18 })
            .textAlign(TextAlign.Center)

          // 菜单选项
          Column() {
            Row() {
              Image($r('app.media.baseline_edit_24'))
                .width(24).height(24)
                .margin({ right: 12 })
                .fillColor(this.colors.onSurface)
              Text('编辑详情')
                .fontSize(16)
                .fontColor(this.colors.text)
                .flexGrow(1)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onEditDetails(this.authenticator))

            Row() {
              Image($r('app.media.baseline_image_24'))
                .width(24).height(24)
                .margin({ right: 12 })
                .fillColor(this.colors.onSurface)
              Text('更改图标')
                .fontSize(16)
                .fontColor(this.colors.text)
                .flexGrow(1)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onChangeIcon())

            Row() {
              Image($r('app.media.baseline_category_24'))
                .width(24).height(24)
                .margin({ right: 12 })
                .fillColor(this.colors.onSurface)
              Text('指定分类')
                .fontSize(16)
                .fontColor(this.colors.text)
                .flexGrow(1)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onAssignCategory())

            Row() {
              Image($r('app.media.baseline_qr_code_24'))
                .width(24).height(24)
                .margin({ right: 12 })
                .fillColor(this.colors.onSurface)
              Text('显示二维码')
                .fontSize(16)
                .fontColor(this.colors.text)
                .flexGrow(1)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onShowQrCode())

            Row() {
              Image($r('app.media.baseline_delete_24'))
                .width(24).height(24)
                .margin({ right: 12 })
                .fillColor(this.colors.error)
              Text('删除')
                .fontSize(16)
                .fontColor(this.colors.error)
                .flexGrow(1)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16, bottom: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.onDelete())
          }
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
