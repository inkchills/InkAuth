// EmptyState.ets

import { ThemeColors, ThemeManager } from '../../../core/util/ThemeManager';

@Component
export struct EmptyState {
  @Prop isSearching: boolean = false;
  @Prop colors: ThemeColors;
  onGuide: () => void = () => {};
  onImport: () => void = () => {};
  onRestore: () => void = () => {};

  build() {
    Column() {
      if (this.isSearching) {
        // 搜索无结果状态
        Image($r('app.media.baseline_search_24'))
          .width(64)
          .height(64)
          .fillColor(this.colors.textSecondary)
          .margin({ bottom: 16 })

        Text('没有匹配结果')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.onBackground)
          .margin({ bottom: 8 })

        Text('请尝试其他关键词')
          .fontSize(14)
          .fontColor(this.colors.textSecondary)
          .textAlign(TextAlign.Center)
      } else {
        // 空列表状态
        Image(ThemeManager.isDarkColorSet(this.colors) ? $r('app.media.big_ic_logo_dark') : $r('app.media.big_ic_logo'))
          .width(80)
          .height(80)
          .margin({ bottom: 20 })

        Text('这里什么都没有！')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.onBackground)
          .margin({ bottom: 8 })

        Text('您尚未添加验证器。')
          .fontSize(14)
          .fontColor(this.colors.textSecondary)
          .textAlign(TextAlign.Center)
          .margin({ bottom: 8 })

        Text('如果您是 InkAuth 的新用户，请点击下方查看入门指南。')
          .fontSize(13)
          .fontColor(this.colors.textSecondary)
          .textAlign(TextAlign.Center)
          .lineHeight(20)
          .margin({ bottom: 32 })

        // 入门指南按钮

        Column(){
          Row(){
            Image($r('app.media.baseline_help_outline_24'))
              .width(20)
              .height(20)
              .margin({right:8})
              .fillColor(this.colors.onBackground)
            Text('入门指南')
              .fontSize(15)
              .fontColor(this.colors.onBackground)
          }

        }
        .width('100%')
        .height(46)
        .onClick(() => this.onGuide())

        // 从其他应用导入按钮
        Button() {
          Row() {
            Image($r('app.media.baseline_input_24'))
              .width(20)
              .height(20)
              .fillColor(this.colors.onBackground)
              .margin({ right: 8 })
            Text('从其他应用导入')
              .fontSize(15)
              .fontColor(this.colors.onBackground)
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(46)
        .backgroundColor('transparent')
        .border({ width: 1, color: this.colors.border, radius: 23 })
        .margin({ bottom: 12 })
        .onClick(() => this.onImport())

        // 恢复备份按钮
        Button() {
          Row() {
            Image($r('app.media.baseline_restore_24'))
              .width(20)
              .height(20)
              .fillColor(this.colors.onBackground)
              .margin({ right: 8 })
            Text('恢复备份')
              .fontSize(15)
              .fontColor(this.colors.onBackground)
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(46)
        .backgroundColor('transparent')
        .border({ width: 1, color: this.colors.border, radius: 23 })
        .margin({ bottom: 12 })
        .onClick(() => this.onRestore())
      }
    }
    .width('100%')
    .padding({ left: 32, right: 32 })
    .alignItems(HorizontalAlign.Center)
  }
}
