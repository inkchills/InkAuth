interface SheetColors {
  primary: string;
  surface: string;
  background: string;
  onBackground: string;
  textSecondary: string;
  border: string;
  onPrimary: string;
}

@Component
export struct PinUnlockSheet {
  @Prop visible: boolean = false;
  @Prop colors: SheetColors = {
    primary: '#2196F3',
    surface: '#FFFFFF',
    background: '#FFFFFF',
    onBackground: '#000000',
    textSecondary: '#666666',
    onPrimary: '#FFFFFF',
    border: '#E0E0E0'
  };
  @Prop allowBiometrics: boolean = false;
  @Prop isLoading: boolean = false;
  @Prop errorMessage: string = '';
  onCancel: () => void = () => {};
  onConfirm: (pin: string) => void = (pin: string) => {};
  onBiometric: () => void = () => {};

  @State pin: string = '';

  close() {
    this.pin = '';
    this.onCancel();
  }

  confirm() {
    const trimmed = this.pin.trim();
    if (trimmed.length < 4) {
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '密码至少为 4 位', duration: 1500 });
      } catch (e) {
        console.error('Failed to show toast:', e);
      }
      return;
    }
    this.onConfirm(trimmed);
    this.pin = '';
  }

  build() {
    Column() {
      if (this.visible) {
        Stack() {
          Column() {
            Text('')
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.4)')
          }
          .width('100%')
          .height('100%')

          Column() {
            Text('解锁')
              .fontSize(18)
              .fontWeight(700)
              .fontColor(this.colors.onBackground)
              .margin({ bottom: 16 })

            Text('输入您的密码或使用生物识别来解锁数据库')
              .fontSize(13)
              .fontColor(this.colors.textSecondary)
              .margin({ bottom: 16 })

            TextInput({ placeholder: '密码', text: this.pin })
              .type(InputType.Password)
              .width('100%')
              .height(46)
              .padding({ left: 12, right: 12 })
              .backgroundColor(this.colors.surface)
              .border({ width: 1, color: this.colors.border, radius: 8 })
              .fontColor(this.colors.onBackground)
              .onChange((value: string) => this.pin = value)
              .margin({ bottom: 16 })

            if (this.errorMessage) {
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor('#FF5252')
                .margin({ bottom: 8 })
            }

            Row({ space: 10 }) {
              if (this.allowBiometrics) {
                Button('使用生物识别')
                  .height(36)
                  .fontSize(13)
                  .backgroundColor('transparent')
                  .fontColor(this.colors.primary)
                  .onClick(() => this.onBiometric())
              }
              Button(this.isLoading ? '解锁中...' : '解锁')
                .height(36)
                .fontSize(13)
                .enabled(!this.isLoading)
                .backgroundColor(this.colors.primary)
                .fontColor(this.colors.onPrimary)
                .onClick(() => this.confirm())
            }
            .justifyContent(FlexAlign.End)
          }
          .width('80%')
          .padding(20)
          .backgroundColor(this.colors.background)
          .borderRadius(12)
          .zIndex(9101)
        }
      }
    }
  }
}
