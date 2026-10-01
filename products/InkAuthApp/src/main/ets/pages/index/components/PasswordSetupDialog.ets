// PasswordSetupDialog.ets

import { ThemeColors } from '../../../core/util/ThemeManager';

/**
 * 首次使用密码设置对话框
 */
@Component
export struct PasswordSetupDialog {
  @Prop visible: boolean = false;
  @Prop colors: ThemeColors;
  @State private password: string = '';
  @State private confirmPassword: string = '';
  @State private errorMessage: string = '';
  @State private showPassword: boolean = false;

  onSetPassword: (password: string) => void = () => {};
  onSkip: () => void = () => {};

  build() {
    if (this.visible) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.6)')

        // 对话框内容
        Column({ space: 16 }) {
          // 图标
          Image($r('app.media.big_ic_lock'))
            .width(64).height(64)
            .margin({ top: 24 })
            .fillColor(this.colors.primary)

          // 标题
          Text('设置应用密码')
            .fontSize(20)
            .fontWeight(700)
            .fontColor(this.colors.text)

          // 说明
          Text('设置一个密码来保护你的认证器数据。\n每次打开应用时需要输入此密码。')
            .fontSize(14)
            .fontColor(this.colors.textSecondary)
            .textAlign(TextAlign.Center)
            .margin({ left: 24, right: 24 })

          // 密码输入
          Column({ space: 12 }) {
            TextInput({ placeholder: '输入密码', text: this.password })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .width('100%')
              .height(48)
              .borderRadius(8)
              .border({ width: 1, color: this.colors.border, radius: 8 })
              .fontColor(this.colors.text)
              .placeholderColor(this.colors.textSecondary)
              .backgroundColor('transparent')
              .onChange((value: string) => {
                this.password = value;
                this.errorMessage = '';
              })

            TextInput({ placeholder: '确认密码', text: this.confirmPassword })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .width('100%')
              .height(48)
              .borderRadius(8)
              .border({ width: 1, color: this.colors.border, radius: 8 })
              .fontColor(this.colors.text)
              .placeholderColor(this.colors.textSecondary)
              .backgroundColor('transparent')
              .onChange((value: string) => {
                this.confirmPassword = value;
                this.errorMessage = '';
              })

            Row() {
              Checkbox()
                .select(this.showPassword)
                .selectedColor(this.colors.primary)
                .onChange((value: boolean) => {
                  this.showPassword = value;
                })
              Text('显示密码')
                .fontSize(14)
                .fontColor(this.colors.textSecondary)
                .margin({ left: 8 })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 24, right: 24 })

          // 错误提示
          if (this.errorMessage) {
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor(this.colors.error)
              .margin({ left: 24, right: 24 })
          }

          // 按钮区域
          Row({ space: 12 }) {
            Button('跳过')
              .width('40%')
              .height(44)
              .backgroundColor('transparent')
              .fontColor(this.colors.textSecondary)
              .border({ width: 1, color: this.colors.border, radius: 22 })
              .borderRadius(22)
              .onClick(() => {
                this.password = '';
                this.confirmPassword = '';
                this.errorMessage = '';
                this.onSkip();
              })

            Button('确认设置')
              .width('55%')
              .height(44)
              .backgroundColor(this.colors.primary)
              .fontColor(this.colors.onPrimary)
              .borderRadius(22)
              .onClick(() => {
                this.validateAndSetPassword();
              })
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 24 })
        }
        .width('90%')
        .backgroundColor(this.colors.surface)
        .borderRadius(16)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
    }
  }

  private validateAndSetPassword(): void {
    if (this.password.length < 4) {
      this.errorMessage = '密码至少需要4个字符';
      return;
    }
    if (this.password !== this.confirmPassword) {
      this.errorMessage = '两次输入的密码不一致';
      return;
    }
    this.onSetPassword(this.password);
    this.password = '';
    this.confirmPassword = '';
    this.errorMessage = '';
  }
}
