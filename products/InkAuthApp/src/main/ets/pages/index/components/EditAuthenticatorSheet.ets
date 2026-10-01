import { Authenticator } from '../../../core/entity/Authenticator';

interface SheetColors {
  primary: string;
  surface: string;
  background: string;
  onBackground: string;
}

@Component
export struct EditAuthenticatorSheet {
  @Prop visible: boolean = false;
  @Prop auth: Authenticator | null = null;
  @Prop colors: SheetColors = { primary: '#2196F3', surface: '#FFFFFF', background: '#FFFFFF', onBackground: '#000000' };
  onClose: () => void = () => {};
  onSave: (auth: Authenticator) => void = () => {};
  onDelete: (auth: Authenticator) => void = () => {};

  build() {
    Column() {
      // Render sheet only when visible
      if (this.visible) {
        Stack() {
          // backdrop
          Column() {
            Text('')
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0,0,0,0.3)')
              .onClick(() => this.onClose())
          }
          .width('100%')
          .height('100%')

          Column() {
            Text('编辑认证器')
              .fontSize(18)
              .fontWeight(600)
              .fontColor(this.colors.primary)
              .margin({ bottom: 12 })

            if (this.auth) {
              Row() {
                Text('发行者')
                  .width(80)
                  .margin({ right: 8 })
                TextInput({ text: this.auth ? this.auth.issuer : '', placeholder: '发行者' })
                  .width('100%')
                  .height(48)
                  .padding({ left: 8, right: 8 })
                  .onChange((value: string) => { if (this.auth) { this.auth.issuer = value; } })
              }
              .margin({ bottom: 8 })

              Row() {
                Text('用户名')
                  .width(80)
                  .margin({ right: 8 })
                TextInput({ text: this.auth ? this.auth.username : '', placeholder: '用户名' })
                  .width('100%')
                  .height(48)
                  .padding({ left: 8, right: 8 })
                  .onChange((value: string) => { if (this.auth) { this.auth.username = value; } })
              }
              .margin({ bottom: 8 })

              Row() {
                Text('密钥')
                  .width(80)
                  .margin({ right: 8 })
                TextInput({ text: this.auth ? this.auth.secret : '', placeholder: '密钥' })
                  .width('100%')
                  .height(48)
                  .padding({ left: 8, right: 8 })
                  .onChange((value: string) => { if (this.auth) { this.auth.secret = value; } })
              }
              .margin({ bottom: 8 })

              Row() {
                Button('保存')
                  .width('48%')
                  .onClick(() => { if (this.auth) { this.onSave(this.auth); } })
                Button('删除')
                  .width('48%')
                  .margin({ left: 8 })
                  .backgroundColor('#FF5252')
                  .fontColor('#FFFFFF')
                  .onClick(() => { if (this.auth) { this.onDelete(this.auth); } })
              }
              .margin({ top: 16 })
            }

            Button('取消')
              .width('100%')
              .margin({ top: 8 })
              .onClick(() => this.onClose())
          }
          .width('92%')
          .padding(16)
          .backgroundColor(this.colors.surface)
          .borderRadius(12)
          .position({ x: '4%', y: '40%' })
          .zIndex(9002)
        }
      }
    }
  }
}
