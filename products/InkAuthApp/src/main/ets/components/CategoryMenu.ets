// CategoryMenu.ets

@Component
export struct CategoryMenu {
  @Prop visible: boolean;
  onBack: () => void = () => {};
  onAddCategory: () => void = () => {};

  build() {
    if (this.visible) {
      Column() {
        Column() {
          Row() {
            Image($r('app.media.baseline_arrow_back_24'))
              .width(24).height(24)
              .onClick(() => this.onBack())
            Text('分类')
              .fontSize(18)
              .fontWeight(700)
              .flexGrow(1)
              .textAlign(TextAlign.Center)
            Text('')
              .width(24)
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)

          List() {
            ListItem() {
              Row() {
                Text('暂无分类')
                  .fontSize(16)
                  .fontColor('#9E9E9E')
                  .flexGrow(1)
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)
            }
          }
          .width('100%')
          .flexGrow(1)

          Button('+')
            .width(56)
            .height(56)
            .fontSize(24)
            .fontWeight(700)
            .backgroundColor('#3F51B5')
            .borderRadius(28)
            .margin({ right: 16, bottom: 16 })
            .position({ x: '85%', y: '90%' })
            .onClick(() => this.onAddCategory())
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#ffffff')
      }
      .position({ x: 0, y: 0 })
      .width('100%')
      .height('100%')
      .backgroundColor('#ffffff')
    }
  }
}
