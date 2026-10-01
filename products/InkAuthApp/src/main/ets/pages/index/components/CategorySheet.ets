import { Category } from '../../../core/entity/Category';
import { ThemeColors } from '../../../core/util/ThemeManager';

@Component
export struct CategorySheet {
  @Prop visible: boolean;
  @Prop categories: Category[];
  @Prop colors: ThemeColors;
  onSelect: (category: Category | null) => void = () => {};
  onClose: () => void = () => {};

  build() {
    if (this.visible) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => this.onClose())

        // 底部弹窗
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
          .margin({ top: 8 })

          // 标题
          Text('指定分类')
            .fontSize(18)
            .fontWeight(700)
            .fontColor(this.colors.text)
            .margin({ bottom: 16 })
            .textAlign(TextAlign.Center)
            .width('100%')

          // 分类列表
          List() {
            // 无分类选项
            ListItem() {
              Row() {
                Image($r('app.media.baseline_close_24'))
                   .width(24)
                   .height(24)
                   .margin({ right: 16 })
                   .fillColor(this.colors.textSecondary)
                Text('无分类')
                  .fontSize(16)
                  .fontColor(this.colors.text)
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 12, bottom: 12 })
              .alignItems(VerticalAlign.Center)
            }
            .onClick(() => this.onSelect(null))

            // 现有分类
            ForEach(this.categories, (item: Category) => {
              ListItem() {
                Row() {
                  Image($r('app.media.baseline_folder_24'))
                   .width(24)
                   .height(24)
                   .margin({ right: 16 })
                   .fillColor(this.colors.textSecondary)
                  Text(item.name)
                    .fontSize(16)
                    .fontColor(this.colors.text)
                }
                .width('100%')
                .padding({ left: 24, right: 24, top: 12, bottom: 12 })
                .alignItems(VerticalAlign.Center)
              }
              .onClick(() => this.onSelect(item))
            }, (item: Category) => item.id)
          }
          .width('100%')
          .height(300) // 限制高度
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .backgroundColor(this.colors.surface)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Bottom)
      .zIndex(100)
    }
  }
}
