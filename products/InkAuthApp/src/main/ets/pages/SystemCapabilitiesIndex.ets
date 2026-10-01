import { BreakpointSystem, BreakPointType } from '@ohos/common';

/**
 * SystemCapabilitiesIndex page tests whether the system has the capability of
 * SystemCapability.Location.Location.Core.
 */
@Entry
@Component
struct SystemCapabilitiesIndex {
  @StorageLink('mainBreakpoint') currentBreakpoint: string = 'sm';
  private readonly breakpointSystem: BreakpointSystem = new BreakpointSystem('main');
  private locationCapability: boolean = false;

  aboutToAppear() {
    this.locationCapability = canIUse('SystemCapability.Location.Location.Core');
    this.breakpointSystem.register(this.getUIContext());
  }

  aboutToDisappear() {
    this.breakpointSystem.unregister();
  }

  build() {
    Column() {
      Row() {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .onClick(() => {
              this.getUIContext().getRouter().back();
            })
            .fontColor([$r('sys.color.titlebar_icon_color')])
        }
        .width(24)
        .borderRadius(4)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      }
      .width('100%')
      .height(48)
      .position({ x: 16 })

      Column() {
        Image(this.locationCapability ? $r('app.media.ic_location_yes') : $r('app.media.ic_location_no'))
          .width(100)
          .height(100)
          .margin({ bottom: 16 })
        Text(this.locationCapability ? 'Location capability available' : 'Location capability not available')
          .fontSize(16)
          .fontWeight(400)
          .fontColor(this.locationCapability ?
            $r('sys.color.ohos_id_color_text_tertiary') : $r('sys.color.ohos_id_color_text_secondary'))
          .margin({
            left: 16,
            right: 16
          })
      }
      .width('100%')
    }
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .height('100%')
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}