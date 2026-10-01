// TopBar.ets

import { ThemeColors } from '../../../core/util/ThemeManager';

@Component
export struct TopBar {
  @Prop showSearchBar: boolean = false;
  @Prop searchText: string = '';
  @Prop currentCategoryName: string = '';
  @Prop colors: ThemeColors;
  @StorageProp('insetTopPx') insetTopPx: number = 0;
  onSearchChange: (value: string) => void = () => {};
  onToggleSort: () => void = () => {};
  onBackFromSearch: () => void = () => {};
  onToggleSearch: () => void = () => {};

  build() {
    Column() {
      if (this.showSearchBar) {
        Row() {
          Image($r('app.media.baseline_arrow_back_24'))
            .width(24)
            .height(24)
            .fillColor(this.colors.onBackground)
            .margin({ left: 16 })
            .onClick(() => this.onBackFromSearch())
          TextInput({
            placeholder: '搜索',
            text: this.searchText
          })
            .flexGrow(1)
            .height(42)
            .padding({ left: 16, right: 16 })
            .backgroundColor(this.colors.surface)
            .borderRadius(21)
            .fontColor(this.colors.onSurface)
            .fontSize(16)
            .margin({ left: 10, right: 12 })
            .onChange((value: string) => this.onSearchChange(value))
          Image($r('app.media.baseline_sort_24'))
            .width(26)
            .height(26)
            .fillColor(this.colors.onBackground)
            .margin({ right: 18 })
            .onClick(() => this.onToggleSort())
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.colors.background)
      } else {
        Row() {
          Text(this.currentCategoryName || 'InkAuth')
            .fontSize(24)
            .fontWeight(700)
            .margin({ left: 16 })
            .fontColor(this.colors.onBackground)
          Blank()
            .flexGrow(1)
          Image($r('app.media.baseline_sort_24'))
            .width(30)
            .height(30)
            .fillColor(this.colors.onBackground)
            .margin({ right: 18 })
            .onClick(() => this.onToggleSort())
        }
        .width('100%')
        .height(50)
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .backgroundColor(this.colors.background)
      }
    }
    .width('100%')
    .padding({ top: px2vp(this.insetTopPx) })
    .backgroundColor(this.colors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
