interface DialogColors {
  background: string;
  surface: string;
  onSurface: string;
  border: string;
}

@Component
export struct ImportPasswordDialog {
  @Prop visible: boolean = false;
  @Prop colors: DialogColors = { background: '#FFFFFF', surface: '#FFFFFF', onSurface: '#000000', border: '#E0E0E0' };
  @Prop title: string = '请输入导入密码';
  @Prop placeholder: string = '密码';
  @Prop confirmText: string = '确定';
  @Prop password: string = '';
  onChange: (value: string) => void = () => {};
  onCancel: () => void = () => {};
  onConfirm: () => void = () => {};

  build() {
    Column() {
      if (this.visible) {
        Stack() {
          // backdrop
          Column() {
            Text('')
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.4)')
              .onClick(() => this.onCancel())
          }
          .width('100%')
          .height('100%')

          // dialog content
          Column() {
            Text(this.title)
              .fontSize(18)
              .fontWeight(700)
              .fontColor(this.colors.onSurface)
              .margin({ bottom: 16 })

            TextInput({ placeholder: this.placeholder, text: this.password })
              .type(InputType.Password)
              .width('100%')
              .height(46)
              .padding({ left: 12, right: 12 })
              .backgroundColor(this.colors.surface)
              .border({ width: 1, color: this.colors.border, radius: 8 })
              .fontColor(this.colors.onSurface)
              .onChange((value: string) => this.onChange(value))
              .margin({ bottom: 16 })

            Row() {
              Button('取消')
                .width(100)
                .height(40)
                .margin({ right: 16 })
                .onClick(() => this.onCancel())
              Button(this.confirmText)
                .width(100)
                .height(40)
                .onClick(() => this.onConfirm())
            }
            .justifyContent(FlexAlign.Center)
          }
          .width('80%')
          .padding(20)
          .backgroundColor(this.colors.background)
          .borderRadius(12)
          .position({ x: '10%', y: '35%' })
          .zIndex(9101)
        }
      }
    }
  }
}
