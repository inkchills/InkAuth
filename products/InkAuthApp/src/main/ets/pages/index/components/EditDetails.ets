// EditDetails.ets

import { Authenticator } from '../../../core/entity/Authenticator';
import { AuthenticatorType } from '../../../core/AuthenticatorType';
import { HashAlgorithm } from '../../../core/generator/HashAlgorithm';
import { SecretUtil } from '../../../core/util/SecretUtil';
import { ThemeColors } from '../../../core/util/ThemeManager';

interface TypeOption {
  label: string;
  value: AuthenticatorType;
}

interface AlgorithmOption {
  label: string;
  value: HashAlgorithm;
}

@Component
export struct EditDetails {
  @Prop visible: boolean;
  @Prop authenticator: Authenticator | null;
  @Prop colors: ThemeColors;
  onCancel: () => void = () => {};
  onSave: (updatedAuth: Authenticator) => void = () => {};

  @State private showAdvancedOptions: boolean = false;
  @State private showWarningDialog: boolean = false;
  @State private showTypePicker: boolean = false;
  @State private showAlgorithmPicker: boolean = false;
  @State private showSecret: boolean = false;

  @State private issuer: string = '';
  @State private username: string = '';
  @State private secret: string = '';
  @State private algorithm: HashAlgorithm = HashAlgorithm.Sha1;
  @State private digits: number = 6;
  @State private period: number = 30;
  @State private type: AuthenticatorType = AuthenticatorType.Totp;
  @State private counter: number = 0;
  @State private pin: string = '';

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

  aboutToAppear() {
    this.syncFromAuthenticator();
  }

  private resetOnOpen(): void {
    this.showAdvancedOptions = false;
    this.showWarningDialog = false;
    this.showTypePicker = false;
    this.showAlgorithmPicker = false;
    this.showSecret = false;
    this.syncFromAuthenticator();
  }

  private syncFromAuthenticator(): void {
    if (this.authenticator) {
      this.issuer = this.authenticator.issuer || '';
      this.username = this.authenticator.username || '';
      this.secret = this.authenticator.secret || '';
      this.algorithm = this.authenticator.algorithm || HashAlgorithm.Sha1;
      this.digits = this.authenticator.digits || 6;
      this.period = this.authenticator.period || 30;
      this.type = this.authenticator.type || AuthenticatorType.Totp;
      this.counter = this.authenticator.counter || 0;
      this.pin = this.authenticator.pin || '';
    }
  }

  private getTypeLabel(): string {
    for (let i = 0; i < this.typeOptions.length; i++) {
      if (this.typeOptions[i].value === this.type) {
        return this.typeOptions[i].label;
      }
    }
    return this.type.toString();
  }

  private getAlgorithmLabel(): string {
    for (let i = 0; i < this.algorithmOptions.length; i++) {
      if (this.algorithmOptions[i].value === this.algorithm) {
        return this.algorithmOptions[i].label;
      }
    }
    return this.algorithm.toString();
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

    if (this.digits < 6 || this.digits > 10) {
      try { prompt.showToast({ message: '位数必须在6-10之间', duration: 1500 }); } catch (_e) {}
      return;
    }

    if (this.period <= 0) {
      try { prompt.showToast({ message: '时间间隔必须大于0', duration: 1500 }); } catch (_e) {}
      return;
    }

    if (this.type === AuthenticatorType.Hotp && this.counter < 0) {
      try { prompt.showToast({ message: '计数器必须大于等于0', duration: 1500 }); } catch (_e) {}
      return;
    }

    if (this.type === AuthenticatorType.MobileOtp && !this.pin.trim()) {
      try { prompt.showToast({ message: 'PIN不能为空', duration: 1500 }); } catch (_e) {}
      return;
    }

    const updatedAuth = new Authenticator();
    updatedAuth.issuer = this.issuer.trim();
    updatedAuth.username = this.username.trim();
    updatedAuth.secret = this.secret.trim().toUpperCase().replace(/[^A-Z2-7=]/g, '');
    updatedAuth.algorithm = this.algorithm;
    updatedAuth.digits = this.digits;
    updatedAuth.period = this.period;
    updatedAuth.type = this.type;
    updatedAuth.counter = this.counter;
    updatedAuth.pin = this.pin.trim() || null;

    this.onSave(updatedAuth);
  }

  build() {
    if (this.visible && this.authenticator) {
      Stack() {
        // 背景遮罩
        Column() {
          Text('')
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => this.onCancel())
        }
        .width('100%')
        .height('100%')

        // 编辑详情内容
        Column() {
          Text('编辑详情')
            .fontSize(18)
            .fontWeight(700)
            .fontColor(this.colors.text)
            .margin({ top: 24, bottom: 24 })
            .textAlign(TextAlign.Center)

          Scroll() {
            Column() {
              // 发行方
              Column() {
                Row() {
                  Text('发行方 (如: Google)')
                    .fontSize(14)
                    .fontColor(this.colors.textSecondary)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${this.issuer.length}/32`)
                    .fontSize(12)
                    .fontColor(this.colors.textSecondary)
                    .flexShrink(0)
                    .margin({ left: 8 })
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .margin({ bottom: 8 })

                TextInput({
                  text: this.issuer,
                  placeholder: '请输入发行方'
                })
                  .width('92%')
                  .height(48)
                  .padding({ left: 16, right: 16 })
                  .border({ width: 2, color: this.colors.primary, radius: 8 })
                  .maxLength(32)
                  .fontColor(this.colors.text)
                  .placeholderColor(this.colors.textSecondary)
                  .onChange((value: string) => {
                    this.issuer = value;
                  })
                  .margin({ bottom: 16 })
              }

              // 用户名
              Column() {
                Row() {
                  Text('用户名 (如: john@example.com)')
                    .fontSize(14)
                    .fontColor(this.colors.textSecondary)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${this.username.length}/40`)
                    .fontSize(12)
                    .fontColor(this.colors.textSecondary)
                    .flexShrink(0)
                    .margin({ left: 8 })
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .margin({ bottom: 8 })

                TextInput({
                  text: this.username,
                  placeholder: '请输入用户名'
                })
                  .width('92%')
                  .height(48)
                  .padding({ left: 16, right: 16 })
                  .border({ width: 1, color: this.colors.border, radius: 8 })
                  .maxLength(40)
                  .fontColor(this.colors.text)
                  .placeholderColor(this.colors.textSecondary)
                  .onChange((value: string) => {
                    this.username = value;
                  })
                  .margin({ bottom: 16 })
              }

              // 显示高级选项按钮
              Button('显示高级选项')
                .width('92%')
                .height(48)
                .margin({ bottom: 16 })
                .fontSize(16)
                .fontColor(this.colors.primary)
                .backgroundColor('transparent')
                .border({ width: 1, color: this.colors.border, radius: 8 })
                .onClick(() => {
                  this.showWarningDialog = true;
                })

              // 高级选项
              if (this.showAdvancedOptions) {
                Column() {
                  // 类型
                  Text('类型')
                    .fontSize(14)
                    .fontColor(this.colors.textSecondary)
                    .margin({ left: 16, right: 16, bottom: 8 })
                  Text(this.getTypeLabel())
                    .width('92%')
                    .height(48)
                    .padding({ left: 16, right: 16 })
                    .border({ width: 1, color: this.colors.border, radius: 8 })
                    .fontSize(16)
                    .fontColor(this.colors.text)
                    .margin({ bottom: 16 })
                    .onClick(() => { this.showTypePicker = true; })

                  // 密钥
                  Text('密钥')
                    .fontSize(14)
                    .fontColor(this.colors.textSecondary)
                    .margin({ left: 16, right: 16, bottom: 8 })
                  TextInput({
                    text: this.secret,
                    placeholder: '请输入密钥'
                  })
                    .type(this.showSecret ? InputType.Normal : InputType.Password)
                    .width('92%')
                    .height(48)
                    .padding({ left: 16, right: 16 })
                    .border({ width: 1, color: this.colors.border, radius: 8 })
                    .fontColor(this.colors.text)
                    .placeholderColor(this.colors.textSecondary)
                    .onChange((value: string) => { this.secret = value; })
                    .margin({ bottom: 16 })

                  // 算法
                  Text('算法')
                    .fontSize(14)
                    .fontColor(this.colors.textSecondary)
                    .margin({ left: 16, right: 16, bottom: 8 })
                  Text(this.getAlgorithmLabel())
                    .width('92%')
                    .height(48)
                    .padding({ left: 16, right: 16 })
                    .border({ width: 1, color: this.colors.border, radius: 8 })
                    .fontSize(16)
                    .fontColor(this.colors.text)
                    .margin({ bottom: 16 })
                    .onClick(() => { this.showAlgorithmPicker = true; })

                  // 位数和时间间隔（上下排列，避免并排裁切）
                  Column() {
                    Text('位数')
                      .fontSize(14)
                      .fontColor(this.colors.textSecondary)
                      .margin({ bottom: 8 })
                    TextInput({ text: this.digits.toString() })
                      .width('100%')
                      .height(48)
                      .padding({ left: 16, right: 16 })
                      .border({ width: 1, color: this.colors.border, radius: 8 })
                      .fontColor(this.colors.text)
                      .onChange((value: string) => { this.digits = parseInt(value) || 6; })
                  }
                  .width('92%')
                  .margin({ bottom: 16 })

                  Column() {
                    Text('时间间隔 (秒)')
                      .fontSize(14)
                      .fontColor(this.colors.textSecondary)
                      .margin({ bottom: 8 })
                    TextInput({ text: this.period.toString() })
                      .width('100%')
                      .height(48)
                      .padding({ left: 16, right: 16 })
                      .border({ width: 1, color: this.colors.border, radius: 8 })
                      .fontColor(this.colors.text)
                      .onChange((value: string) => { this.period = parseInt(value) || 30; })
                  }
                  .width('92%')
                  .margin({ bottom: 16 })

                  // 计数器 (仅HOTP)
                  if (this.type === AuthenticatorType.Hotp) {
                    Column() {
                      Text('计数器')
                        .fontSize(14)
                        .fontColor(this.colors.textSecondary)
                        .margin({ bottom: 8 })
                      TextInput({ text: this.counter.toString() })
                        .width('100%')
                        .height(48)
                        .padding({ left: 16, right: 16 })
                        .border({ width: 1, color: this.colors.border, radius: 8 })
                        .fontColor(this.colors.text)
                        .onChange((value: string) => { this.counter = parseInt(value) || 0; })
                    }
                    .width('92%')
                    .margin({ bottom: 16 })
                  }

                  // PIN (仅mOTP)
                  if (this.type === AuthenticatorType.MobileOtp) {
                    Column() {
                      Text('PIN')
                        .fontSize(14)
                        .fontColor(this.colors.textSecondary)
                        .margin({ bottom: 8 })
                      TextInput({
                        text: this.pin,
                        placeholder: '请输入PIN'
                      })
                        .type(InputType.Password)
                        .width('100%')
                        .height(48)
                        .padding({ left: 16, right: 16 })
                        .border({ width: 1, color: this.colors.border, radius: 8 })
                        .fontColor(this.colors.text)
                        .placeholderColor(this.colors.textSecondary)
                        .onChange((value: string) => { this.pin = value; })
                    }
                    .width('92%')
                    .margin({ bottom: 16 })
                  }
                }
              }
            }
          }
          .layoutWeight(1)

          // 按钮
          Row() {
            Button('取消')
              .width('48%')
              .height(48)
              .fontSize(16)
              .fontColor(this.colors.textSecondary)
              .backgroundColor('transparent')
              .border({ width: 1, color: this.colors.border, radius: 8 })
              .onClick(() => { this.onCancel(); })

            Button('保存')
              .width('48%')
              .height(48)
              .fontSize(16)
              .fontColor(this.colors.onPrimary)
              .backgroundColor(this.colors.primary)
              .borderRadius(8)
              .onClick(() => { this.handleSave(); })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .padding({ left: 16, right: 16, bottom: 32 })
        }
        .onAppear(() => { this.resetOnOpen(); })
        .width('100%')
        .height('80%')
        .backgroundColor(this.colors.surface)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .position({ x: 0, y: '20%' })

        // 警告对话框
        if (this.showWarningDialog) {
          Column() {
            Text('')
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick(() => { this.showWarningDialog = false; })
          }
          .width('100%')
          .height('100%')

          Column() {
            Image($r('app.media.baseline_warning_24'))
              .width(48).height(48)
              .fillColor('#FF9800')
              .margin({ top: 24, bottom: 16 })
            Text('警告')
              .fontSize(18)
              .fontWeight(700)
              .fontColor(this.colors.text)
              .margin({ bottom: 16 })
            Text('除非你明确知道自己在做什么，否则不建议更改这些选项。错误的更改可能导致无法访问你的账户。')
              .fontSize(14)
              .fontColor(this.colors.textSecondary)
              .margin({ left: 24, right: 24, bottom: 24 })
              .textAlign(TextAlign.Center)
            Row() {
              Button('取消')
                .width('48%')
                .height(48)
                .fontSize(16)
                .fontColor(this.colors.textSecondary)
                .backgroundColor('transparent')
                .border({ width: 1, color: this.colors.border, radius: 8 })
                .onClick(() => { this.showWarningDialog = false; })
              Button('确定')
                .width('48%')
                .height(48)
                .fontSize(16)
                .fontColor(this.colors.onPrimary)
                .backgroundColor(this.colors.primary)
                .borderRadius(8)
                .onClick(() => {
                  this.showWarningDialog = false;
                  this.showAdvancedOptions = true;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .padding({ left: 24, right: 24, bottom: 24 })
          }
          .width('80%')
          .backgroundColor(this.colors.surface)
          .borderRadius(16)
          .position({ x: '10%', y: '30%' })
        }

        // 类型选择器
        if (this.showTypePicker) {
          Column() {
            Text('')
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick(() => { this.showTypePicker = false; })
          }
          .width('100%')
          .height('100%')

          Column() {
            Text('选择类型')
              .fontSize(16)
              .fontWeight(700)
              .fontColor(this.colors.text)
              .margin({ top: 24, bottom: 16, left: 24 })
            List() {
              ForEach(this.typeOptions, (option: TypeOption) => {
                ListItem() {
                  Text(option.label)
                    .fontSize(16)
                    .fontColor(this.colors.text)
                    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
                    .onClick(() => {
                      this.type = option.value;
                      this.showTypePicker = false;
                    })
                }
              })
            }
            .width('100%')

            Button('取消')
              .width('90%')
              .height(48)
              .fontSize(16)
              .fontColor(this.colors.textSecondary)
              .backgroundColor('transparent')
              .border({ width: 1, color: this.colors.border, radius: 8 })
              .margin({ top: 16, bottom: 24 })
              .onClick(() => { this.showTypePicker = false; })
          }
          .width('80%')
          .backgroundColor(this.colors.surface)
          .borderRadius(16)
          .position({ x: '10%', y: '25%' })
        }

        // 算法选择器
        if (this.showAlgorithmPicker) {
          Column() {
            Text('')
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick(() => { this.showAlgorithmPicker = false; })
          }
          .width('100%')
          .height('100%')

          Column() {
            Text('选择算法')
              .fontSize(16)
              .fontWeight(700)
              .fontColor(this.colors.text)
              .margin({ top: 24, bottom: 16, left: 24 })
            List() {
              ForEach(this.algorithmOptions, (option: AlgorithmOption) => {
                ListItem() {
                  Text(option.label)
                    .fontSize(16)
                    .fontColor(this.colors.text)
                    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
                    .onClick(() => {
                      this.algorithm = option.value;
                      this.showAlgorithmPicker = false;
                    })
                }
              })
            }
            .width('100%')

            Button('取消')
              .width('90%')
              .height(48)
              .fontSize(16)
              .fontColor(this.colors.textSecondary)
              .backgroundColor('transparent')
              .border({ width: 1, color: this.colors.border, radius: 8 })
              .margin({ top: 16, bottom: 24 })
              .onClick(() => { this.showAlgorithmPicker = false; })
          }
          .width('80%')
          .backgroundColor(this.colors.surface)
          .borderRadius(16)
          .position({ x: '10%', y: '25%' })
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}
