interface SheetColors {
  primary: string;
  surface: string;
  background: string;
  onBackground: string;
}

@Component
export struct AddMenuSheet {
  @Prop visible: boolean = false;
  @Prop colors: SheetColors = { primary: '#2196F3', surface: '#FFFFFF', background: '#FFFFFF', onBackground: '#000000' };
  onClose: () => void = () => {};
  onScan: () => void = () => {};
  onEnterKey: () => void = () => {};
  onRestore: () => void = () => {};
  onImport: () => void = () => {};

  build() {
    // Ensure the build method always has a single root container
    Column() {
      if (this.visible) {
        Stack() {
          Column() {
            Text('')
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.2)')
              .onClick(() => this.onClose())
          }
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(9000)

          Column({ space: 0 }) {
            Row() {
              Text('')
                .width(44)
                .height(5)
                .backgroundColor(this.handleColor())
                .borderRadius(3)
            }
            .width('100%')
            .height(32)
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)

            Row() {
              Text('添加')
                .fontSize(18)
                .fontWeight(700)
                .margin({ bottom: 18 })
                .fontColor(this.colors.primary)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.colors.surface)

            Column({ space: 0 }) {
              this.renderItem('app.media.baseline_qr_code_24', '扫描二维码', this.onScan)
              this.renderItem('app.media.baseline_vpn_key_24', '输入提供的密钥', this.onEnterKey)
              this.renderItem('app.media.baseline_restore_24', '从备份中恢复', this.onRestore)
              this.renderItem('app.media.baseline_input_24', '从其他应用导入', this.onImport)
            }
          }
          .width('100%')
          .backgroundColor(this.colors.surface)
          .borderRadius({ topLeft: 20, topRight: 20 })
          .padding({ bottom: 12 })
          .zIndex(9001)
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.Bottom)
      }
    }
    .width(this.visible ? '100%' : 0)
    .height(this.visible ? '100%' : 0)
  }

  @Builder
  private renderItem(icon: string, label: string, onClick: () => void) {
    Row() {
      Image($r(icon))
        .width(24)
        .height(24)
        .fillColor(this.colors.onBackground)
        .margin({ left: 16, right: 16 })
      Text(label)
        .fontSize(16)
        .fontColor(this.colors.onBackground)
        .flexGrow(1)
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.colors.surface)
    .onClick(() => onClick())
  }

  private handleColor(): string {
    return this.colors.onBackground === '#E4E1E9' ? '#D0CDD7' : '#C7C5D0';
  }
}
