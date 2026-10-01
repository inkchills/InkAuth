// InputOTPKey.ets - 手动输入OTP密钥组件 (含高级选项)

import { Authenticator } from '../../../core/entity/Authenticator';
import { AuthenticatorType } from '../../../core/AuthenticatorType';
import { HashAlgorithm } from '../../../core/generator/HashAlgorithm';
import { SecretUtil } from '../../../core/util/SecretUtil';
import { ThemeManager, ThemeColors } from '../../../core/util/ThemeManager';

interface TypeOption {
  label: string;
  value: AuthenticatorType;
}

interface AlgorithmOption {
  label: string;
  value: HashAlgorithm;
}

@Component
export struct InputOTPKey {
  @Prop visible: boolean;
  @StorageProp('insetTopPx') insetTopPx: number = 0;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;
  onCancel: () => void = () => {};
  onSave: (auth: Authenticator) => void = () => {};

  private themeManager: ThemeManager = ThemeManager.getInstance();

  // 基本字段
  @State private issuer: string = '';
  @State private username: string = '';
  @State private secret: string = '';
  @State private type: AuthenticatorType = AuthenticatorType.Totp;

  // 高级选项字段
  @State private algorithm: HashAlgorithm = HashAlgorithm.Sha1;
  @State private digits: number = 6;
  @State private period: number = 30;
  @State private counter: number = 0;
  @State private pin: string = '';

  // UI 状态
  @State private showTypePicker: boolean = false;
  @State private showAlgorithmPicker: boolean = false;
  @State private showAdvancedOptions: boolean = false;
  @State private showWarningDialog: boolean = false;

  private typeOptions: Array<TypeOption> = [
    { label: '基于时间 (TOTP)', value: AuthenticatorType.Totp },
    { label: '基于计数器 (HOTP)', value: AuthenticatorType.Hotp },
    { label: 'Mobile-OTP (mOTP)', value: AuthenticatorType.MobileOtp },
    { label: 'Steam', value: AuthenticatorType.SteamOtp },
    { label: 'Yandex', value: AuthenticatorType.YandexOtp }
  ];

  private algorithmOptions: Array<AlgorithmOption> = [
    { label: 'SHA1 (默认)', value: HashAlgorithm.Sha1 },
    { label: 'SHA256', value: HashAlgorithm.Sha256 },
    { label: 'SHA512', value: HashAlgorithm.Sha512 }
  ];

  private getColors(): ThemeColors {
    return this.themeManager.getColors();
  }

  private getTypeLabel(): string {
    for (let i = 0; i < this.typeOptions.length; i++) {
      if (this.typeOptions[i].value === this.type) {
        return this.typeOptions[i].label;
      }
    }
    return '基于时间 (TOTP)';
  }

  private getAlgorithmLabel(): string {
    for (let i = 0; i < this.algorithmOptions.length; i++) {
      if (this.algorithmOptions[i].value === this.algorithm) {
        return this.algorithmOptions[i].label;
      }
    }
    return 'SHA1 (默认)';
  }

  private resetFields(): void {
    this.issuer = '';
    this.username = '';
    this.secret = '';
    this.type = AuthenticatorType.Totp;
    this.algorithm = HashAlgorithm.Sha1;
    this.digits = 6;
    this.period = 30;
    this.counter = 0;
    this.pin = '';
    this.showAdvancedOptions = false;
  }

  private handleSave(): void {
    const prompt = this.getUIContext().getPromptAction();
    if (!this.issuer.trim()) {
      try { prompt.showToast({ message: '发行方不能为空', duration: 1500 }); } catch (_e) {}
      return;
    }
    if (!this.secret.trim()) {
      try { prompt.showToast({ message: '密钥不能为空', duration: 1500 }); } catch (_e) {}
      return;
    }

    try {
      SecretUtil.validate(this.secret, this.type);
    } catch (error) {
      try { prompt.showToast({ message: '密钥格式错误', duration: 1500 }); } catch (_e) {}
      return;
    }

    const auth = new Authenticator();
    auth.issuer = this.issuer.trim();
    auth.username = this.username.trim();
    auth.secret = this.secret.trim().toUpperCase();
    auth.type = this.type;
    auth.algorithm = this.algorithm;
    auth.digits = this.type === AuthenticatorType.SteamOtp ? 5 : this.digits;
    auth.period = this.period;
    auth.counter = this.counter;
    auth.pin = this.pin;

    this.resetFields();
    this.onSave(auth);
  }

  build() {
    if (this.visible) {
      Stack() {
        // 半透明背景
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick((): void => {
            this.resetFields();
            this.onCancel();
          })

        Column({ space: 0 }) {
          // 顶部栏（含状态栏安全区，保证关闭/完成可点）
          Column() {
            Row() {
              Row() {
                Image($r('app.media.baseline_close_24'))
                  .width(24).height(24)
                  .fillColor(this.getColors().onBackground)
              }
              .width(44)
              .height(44)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .onClick((): void => {
                this.resetFields();
                this.onCancel();
              })

              Text('输入提供的密钥')
                .fontSize(18)
                .fontWeight(700)
                .fontColor(this.getColors().text)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ left: 4, right: 4 })
                .textAlign(TextAlign.Center)

              Row() {
                Image($r('app.media.baseline_done_24'))
                  .width(24).height(24)
                  .fillColor(this.getColors().primary)
              }
              .width(44)
              .height(44)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .onClick((): void => {
                this.handleSave();
              })
            }
            .width('100%')
            .height(56)
            .padding({ left: 8, right: 8 })
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding({ top: px2vp(this.insetTopPx) > 1 ? px2vp(this.insetTopPx) : 36 })
          .backgroundColor(this.getColors().background)

          Divider().color(this.getColors().border).width('100%')

          // 表单内容
          Scroll() {
            Column({ space: 16 }) {
              // 发行方
              Column({ space: 4 }) {
                Text('发行方')
                  .fontSize(13)
                  .fontColor(this.getColors().textSecondary)
                TextInput({ placeholder: '例如: Google', text: this.issuer })
                  .width('100%')
                  .height(48)
                  .borderRadius(8)
                  .backgroundColor(this.getColors().surface)
                  .fontColor(this.getColors().text)
                  .onChange((v: string): void => { this.issuer = v; })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 用户名
              Column({ space: 4 }) {
                Text('用户名')
                  .fontSize(13)
                  .fontColor(this.getColors().textSecondary)
                TextInput({ placeholder: '例如: user@example.com', text: this.username })
                  .width('100%')
                  .height(48)
                  .borderRadius(8)
                  .backgroundColor(this.getColors().surface)
                  .fontColor(this.getColors().text)
                  .onChange((v: string): void => { this.username = v; })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 密钥
              Column({ space: 4 }) {
                Text('密钥')
                  .fontSize(13)
                  .fontColor(this.getColors().textSecondary)
                TextInput({ placeholder: '输入密钥', text: this.secret })
                  .width('100%')
                  .height(48)
                  .borderRadius(8)
                  .backgroundColor(this.getColors().surface)
                  .fontColor(this.getColors().text)
                  .type(InputType.Normal)
                  .onChange((v: string): void => { this.secret = v; })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 类型选择
              Column({ space: 4 }) {
                Text('类型')
                  .fontSize(13)
                  .fontColor(this.getColors().textSecondary)
                Row() {
                  Text(this.getTypeLabel())
                    .fontSize(16)
                    .fontColor(this.getColors().text)
                    .flexGrow(1)
                  Image($r('app.media.baseline_chevron_right_24'))
                    .width(20).height(20)
                    .fillColor(this.getColors().textSecondary)
                }
                .width('100%')
                .height(48)
                .padding({ left: 12, right: 12 })
                .borderRadius(8)
                .backgroundColor(this.getColors().surface)
                .alignItems(VerticalAlign.Center)
                .onClick((): void => {
                  this.showTypePicker = true;
                })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 显示高级选项按钮
              if (!this.showAdvancedOptions) {
                Button('显示高级选项')
                  .width('100%')
                  .height(48)
                  .fontSize(16)
                  .fontColor(this.getColors().primary)
                  .backgroundColor('transparent')
                  .border({ width: 1, color: this.getColors().border, radius: 8 })
                  .onClick((): void => {
                    this.showAdvancedOptions = true;
                  })
              }

              // 高级选项区域
              if (this.showAdvancedOptions) {
                Divider().color(this.getColors().border).width('100%')

                Text('高级选项')
                  .fontSize(13)
                  .fontWeight(600)
                  .fontColor(this.getColors().primary)

                // 算法
                Column({ space: 4 }) {
                  Text('算法')
                    .fontSize(13)
                    .fontColor(this.getColors().textSecondary)
                  Row() {
                    Text(this.getAlgorithmLabel())
                      .fontSize(16)
                      .fontColor(this.getColors().text)
                      .flexGrow(1)
                    Image($r('app.media.baseline_chevron_right_24'))
                      .width(20).height(20)
                      .fillColor(this.getColors().textSecondary)
                  }
                  .width('100%')
                  .height(48)
                  .padding({ left: 12, right: 12 })
                  .borderRadius(8)
                  .backgroundColor(this.getColors().surface)
                  .alignItems(VerticalAlign.Center)
                  .onClick((): void => {
                    this.showAlgorithmPicker = true;
                  })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                // 位数和时间间隔（上下排列，避免并排被裁切）
                Column({ space: 4 }) {
                  Text('位数')
                    .fontSize(13)
                    .fontColor(this.getColors().textSecondary)
                  TextInput({ text: this.digits.toString() })
                    .width('100%')
                    .height(48)
                    .borderRadius(8)
                    .backgroundColor(this.getColors().surface)
                    .fontColor(this.getColors().text)
                    .type(InputType.Number)
                    .onChange((v: string): void => { this.digits = parseInt(v) || 6; })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Column({ space: 4 }) {
                  Text('时间间隔 (秒)')
                    .fontSize(13)
                    .fontColor(this.getColors().textSecondary)
                  TextInput({ text: this.period.toString(), placeholder: '30' })
                    .width('100%')
                    .height(48)
                    .borderRadius(8)
                    .backgroundColor(this.getColors().surface)
                    .fontColor(this.getColors().text)
                    .type(InputType.Number)
                    .onChange((v: string): void => {
                      let val = parseInt(v);
                      if (isNaN(val) || val <= 0) val = 30;
                      this.period = val;
                    })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                // 计数器 (仅 HOTP)
                if (this.type === AuthenticatorType.Hotp) {
                  Column({ space: 4 }) {
                    Text('计数器')
                      .fontSize(13)
                      .fontColor(this.getColors().textSecondary)
                    TextInput({ text: this.counter.toString() })
                      .width('100%')
                      .height(48)
                      .borderRadius(8)
                      .backgroundColor(this.getColors().surface)
                      .fontColor(this.getColors().text)
                      .type(InputType.Number)
                      .onChange((v: string): void => { this.counter = parseInt(v) || 0; })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }

                // PIN (仅 mOTP)
                if (this.type === AuthenticatorType.MobileOtp) {
                  Column({ space: 4 }) {
                    Text('PIN')
                      .fontSize(13)
                      .fontColor(this.getColors().textSecondary)
                    TextInput({ placeholder: '请输入 PIN', text: this.pin })
                      .width('100%')
                      .height(48)
                      .borderRadius(8)
                      .backgroundColor(this.getColors().surface)
                      .fontColor(this.getColors().text)
                      .type(InputType.Password)
                      .onChange((v: string): void => { this.pin = v; })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
              }
            }
            .padding({ left: 16, right: 16, top: 16, bottom: 32 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.getColors().background)

        // 高级选项警告对话框
        if (this.showWarningDialog) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick((): void => { this.showWarningDialog = false; })

            Column({ space: 16 }) {
              Image($r('app.media.baseline_warning_24'))
                .width(48).height(48)
                .fillColor('#FF9800')

              Text('警告')
                .fontSize(18)
                .fontWeight(700)
                .fontColor(this.getColors().text)

              Text('除非你明确知道自己在做什么，否则不建议更改这些选项。错误的更改可能导致无法访问你的账户。')
                .fontSize(14)
                .fontColor(this.getColors().textSecondary)
                .textAlign(TextAlign.Center)

              Row({ space: 12 }) {
                Button('取消')
                  .height(40)
                  .backgroundColor(this.getColors().surface)
                  .fontColor(this.getColors().text)
                  .borderRadius(20)
                  .flexGrow(1)
                  .onClick((): void => { this.showWarningDialog = false; })
                Button('确定')
                  .height(40)
                  .backgroundColor(this.getColors().primary)
                  .fontColor(this.getColors().onPrimary)
                  .borderRadius(20)
                  .flexGrow(1)
                  .onClick((): void => {
                    this.showWarningDialog = false;
                    this.showAdvancedOptions = true;
                  })
              }
              .width('100%')
            }
            .width('85%')
            .padding(20)
            .backgroundColor(this.getColors().background)
            .borderRadius(16)
          }
          .width('100%')
          .height('100%')
          .zIndex(200)
        }

        // 类型选择对话框
        if (this.showTypePicker) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick((): void => { this.showTypePicker = false; })

            Column({ space: 0 }) {
              Text('类型')
                .fontSize(18)
                .fontWeight(700)
                .fontColor(this.getColors().text)
                .margin({ top: 16, bottom: 12 })

              List() {
                ForEach(this.typeOptions, (opt: TypeOption, _index: number) => {
                  ListItem() {
                    Row() {
                      Text(opt.label)
                        .fontSize(16)
                        .fontColor(opt.value === this.type ? this.getColors().primary : this.getColors().text)
                        .fontWeight(opt.value === this.type ? FontWeight.Bold : FontWeight.Normal)
                        .flexGrow(1)
                      if (opt.value === this.type) {
                        Image($r('app.media.baseline_done_24'))
                          .width(20).height(20)
                          .fillColor(this.getColors().primary)
                      }
                    }
                    .width('100%')
                    .height(48)
                    .padding({ left: 20, right: 20 })
                    .onClick((): void => {
                      this.type = opt.value;
                      this.showTypePicker = false;
                    })
                  }
                })
              }
              .width('100%')

              Button('取消')
                .width('90%')
                .height(44)
                .backgroundColor(this.getColors().surface)
                .fontColor(this.getColors().text)
                .borderRadius(22)
                .margin({ top: 8, bottom: 16 })
                .onClick((): void => { this.showTypePicker = false; })
            }
            .width('85%')
            .backgroundColor(this.getColors().background)
            .borderRadius(16)
          }
          .width('100%')
          .height('100%')
          .zIndex(100)
        }

        // 算法选择对话框
        if (this.showAlgorithmPicker) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick((): void => { this.showAlgorithmPicker = false; })

            Column({ space: 0 }) {
              Text('算法')
                .fontSize(18)
                .fontWeight(700)
                .fontColor(this.getColors().text)
                .margin({ top: 16, bottom: 12 })

              List() {
                ForEach(this.algorithmOptions, (opt: AlgorithmOption, _index: number) => {
                  ListItem() {
                    Row() {
                      Text(opt.label)
                        .fontSize(16)
                        .fontColor(opt.value === this.algorithm ? this.getColors().primary : this.getColors().text)
                        .fontWeight(opt.value === this.algorithm ? FontWeight.Bold : FontWeight.Normal)
                        .flexGrow(1)
                      if (opt.value === this.algorithm) {
                        Image($r('app.media.baseline_done_24'))
                          .width(20).height(20)
                          .fillColor(this.getColors().primary)
                      }
                    }
                    .width('100%')
                    .height(48)
                    .padding({ left: 20, right: 20 })
                    .onClick((): void => {
                      this.algorithm = opt.value;
                      this.showAlgorithmPicker = false;
                    })
                  }
                })
              }
              .width('100%')

              Button('取消')
                .width('90%')
                .height(44)
                .backgroundColor(this.getColors().surface)
                .fontColor(this.getColors().text)
                .borderRadius(22)
                .margin({ top: 8, bottom: 16 })
                .onClick((): void => { this.showAlgorithmPicker = false; })
            }
            .width('85%')
            .backgroundColor(this.getColors().background)
            .borderRadius(16)
          }
          .width('100%')
          .height('100%')
          .zIndex(100)
        }
      }
      .width('100%')
      .height('100%')
      .zIndex(9800)
    }
  }
}
