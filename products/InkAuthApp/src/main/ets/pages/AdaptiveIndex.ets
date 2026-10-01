import { adaptiveLayout } from '@ohos/adaptivelayout';
import { CommonConstants } from '../constants/CommonConstants';

/**
 * AdaptiveIndex is the entry of the adaptive layout pages.
 */
@Entry
@Component
struct AdaptiveIndex {
  build() {
    Column() {
      Column() {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize($r('app.float.arrow_width'))
            .onClick(() => {
              this.getUIContext().getRouter().back();
            })
            .fontColor([$r('sys.color.titlebar_icon_color')])
        }
        .width($r('app.float.arrow_width'))
        .borderRadius($r('app.float.arrow_left_borderRadius'))
        .margin({ left: $r('app.float.arrow_margin_left') })
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      }
      .width('100%')
      .height($r('app.float.arrow_item_height'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)

      Column() {
        adaptiveLayout();
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .flexShrink(1)
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}