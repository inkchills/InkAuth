// BottomBar.ets

import { ThemeColors } from '../../../core/util/ThemeManager';

@Component
export struct BottomBar {
  @Prop colors: ThemeColors;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;
  onOpenMenu: () => void = () => {};
  onToggleSearch: () => void = () => {};
  onImport: () => void = () => {};
  onAdd: () => void = () => {};

  private bottomFillVp(): number {
    const measured = px2vp(this.insetBottomPx);
    // Some devices report 0 for navigation indicator; keep a gesture-bar fallback.
    return measured > 1 ? measured : 28;
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.baseline_menu_24'))
          .width(24)
          .height(24)
          .fillColor(this.colors.onBackground)
          .margin({ left: 20, right: 24 })
          .onClick(() => this.onOpenMenu())

        Image($r('app.media.baseline_search_24'))
          .width(24)
          .height(24)
          .fillColor(this.colors.onBackground)
          .onClick(() => this.onToggleSearch())

        Blank()
          .layoutWeight(1)

        Button() {
          Image($r('app.media.baseline_add_24'))
            .width(22)
            .height(22)
            .fillColor(this.colors.onPrimary)
        }
        .width(40)
        .height(40)
        .backgroundColor(this.colors.primary)
        .borderRadius(14)
        .margin({ right: 16 })
        .onClick(() => this.onAdd())
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)

      // Explicit fill into the gesture/home-indicator strip (same color as bar).
      Blank()
        .width('100%')
        .height(this.bottomFillVp())
    }
    .width('100%')
    .backgroundColor(this.colors.surface)
  }
}
