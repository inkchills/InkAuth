// Intro.ets - 首次打开引导页

import { ThemeManager, ThemeColors } from '../core/util/ThemeManager';
import { PasswordService } from '../core/service/impl/PasswordService';
import { common } from '@kit.AbilityKit';

interface IntroPageData {
  icon: Resource;
  title: string;
  summary: string;
  brandLogo?: boolean;
}

@Entry
@Component
struct Intro {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private passwordService: PasswordService = PasswordService.getInstance();
  @State currentIndex: number = 0;
  @State showPasswordSetup: boolean = false;
  @State password: string = '';
  @State confirmPassword: string = '';
  @State showPassword: boolean = false;
  @State passwordError: string = '';
  private swiperController: SwiperController = new SwiperController();

  private pages: IntroPageData[] = [
    {
      icon: ThemeManager.isDarkColorSet(this.themeManager.getColors()) ? $r('app.media.big_ic_logo_dark') : $r('app.media.big_ic_logo'),
      title: '欢迎使用 InkAuth',
      summary: '感谢下载 InkAuth！\n使用开源认证应用保护您的在线账户。',
      brandLogo: true
    },
    {
      icon: $r('app.media.big_ic_lock'),
      title: '双因素认证',
      summary: 'InkAuth 兼容大多数提供商和账户。它与 Google Authenticator 支持的服务 100% 兼容。'
    },
    {
      icon: $r('app.media.big_ic_save'),
      title: '备份与还原',
      summary: '使用强加密备份您的认证器。如果您丢失了设备，您仍然可以访问您的账户。保存到云存储或设备本地。'
    },
    {
      icon: $r('app.media.big_ic_category'),
      title: '分类',
      summary: '将您的认证器整理到不同的分类中，还可以通过简单的长按拖拽来改变顺序。'
    },
    {
      icon: $r('app.media.big_ic_theme'),
      title: '深色主题',
      summary: '如果您喜欢，可以在设置中启用深色主题。所有图标将自动适应新的背景。'
    }
  ];

  getColors(): ThemeColors {
    return this.themeManager.getColors();
  }

  build() {
    Stack() {
      Column() {
        // Swiper 引导页
        Swiper(this.swiperController) {
          ForEach(this.pages, (page: IntroPageData, index: number) => {
            Column() {
              Blank()
                .layoutWeight(1)

              if (page.brandLogo) {
                Image(page.icon)
                  .width(80)
                  .height(80)
                  .margin({ bottom: 24 })
              } else {
                Image(page.icon)
                  .width(80)
                  .height(80)
                  .margin({ bottom: 24 })
                  .fillColor(this.getColors().onBackground)
              }

              Text(page.title)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getColors().text)
                .textAlign(TextAlign.Center)
                .margin({ bottom: 14 })

              Text(page.summary)
                .fontSize(15)
                .fontColor(this.getColors().textSecondary)
                .textAlign(TextAlign.Center)
                .lineHeight(24)
                .padding({ left: 32, right: 32 })

              Blank()
                .layoutWeight(1)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }, (page: IntroPageData, index: number): string => index.toString())
        }
        .layoutWeight(1)
        .indicator(
          new DotIndicator()
            .color(this.getColors().border)
            .selectedColor(this.getColors().primary)
            .itemWidth(8)
            .itemHeight(8)
            .selectedItemWidth(8)
            .selectedItemHeight(8)
        )
        .loop(false)
        .index(this.currentIndex)
        .onChange((index: number) => {
          this.currentIndex = index;
        })

        // 底部导航按钮
        Row() {
          // 上一步按钮
          if (this.currentIndex > 0) {
            Button() {
              Row() {
                Image($r('app.media.baseline_chevron_left_24'))
                  .width(20)
                  .height(20)
                  .fillColor(this.getColors().primary)
                Text('上一步')
                  .fontSize(15)
                  .fontColor(this.getColors().primary)
              }
            }
            .backgroundColor('transparent')
            .onClick(() => {
              this.currentIndex--;
              this.swiperController.showPrevious();
            })
          } else {
            Blank().width(80)
          }

          Blank().layoutWeight(1)

          // 下一步 / 完成按钮
          if (this.currentIndex < this.pages.length - 1) {
            Button() {
              Row() {
                Text('下一步')
                  .fontSize(15)
                  .fontColor(this.getColors().primary)
                Image($r('app.media.baseline_chevron_right_24'))
                  .width(20)
                  .height(20)
                  .fillColor(this.getColors().primary)
              }
            }
            .backgroundColor('transparent')
            .onClick(() => {
              this.currentIndex++;
              this.swiperController.showNext();
            })
          } else {
            Button('开始使用')
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor(this.getColors().primary)
              .borderRadius(20)
              .height(40)
              .padding({ left: 24, right: 24 })
              .onClick(() => {
                this.showPasswordSetup = true;
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 20 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')

      // 密码设置弹窗
      if (this.showPasswordSetup) {
        Column() {
          Column() {
            Image($r('app.media.baseline_lock_24'))
              .width(40)
              .height(40)
              .fillColor(this.getColors().primary)
              .margin({ bottom: 16 })

            Text('设置密码')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getColors().text)
              .margin({ bottom: 8 })

            Text('设置密码以保护您的认证器数据。您也可以跳过此步骤，稍后在设置中配置。')
              .fontSize(13)
              .fontColor(this.getColors().textSecondary)
              .textAlign(TextAlign.Center)
              .lineHeight(20)
              .margin({ bottom: 20 })

            TextInput({ placeholder: '输入密码', text: this.password })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .width('100%')
              .height(48)
              .margin({ bottom: 12 })
              .onChange((value: string) => {
                this.password = value;
                this.passwordError = '';
              })

            TextInput({ placeholder: '确认密码', text: this.confirmPassword })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .width('100%')
              .height(48)
              .margin({ bottom: 8 })
              .onChange((value: string) => {
                this.confirmPassword = value;
                this.passwordError = '';
              })

            Row() {
              Checkbox()
                .select(this.showPassword)
                .onChange((value: boolean) => {
                  this.showPassword = value;
                })
                .width(18)
                .height(18)
                .margin({ right: 8 })
              Text('显示密码')
                .fontSize(13)
                .fontColor(this.getColors().textSecondary)
            }
            .width('100%')
            .margin({ bottom: 8 })

            if (this.passwordError) {
              Text(this.passwordError)
                .fontSize(13)
                .fontColor('#F44336')
                .margin({ bottom: 8 })
            }

            Row() {
              Button('跳过')
                .fontSize(15)
                .fontColor(this.getColors().textSecondary)
                .backgroundColor('transparent')
                .onClick(() => {
                  this.finishIntro();
                })

              Blank().layoutWeight(1)

              Button('设置密码')
                .fontSize(15)
                .fontColor('#FFFFFF')
                .backgroundColor(this.getColors().primary)
                .borderRadius(20)
                .height(40)
                .padding({ left: 20, right: 20 })
                .onClick(() => {
                  this.handleSetPassword();
                })
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .width('90%')
          .constraintSize({ maxWidth: 400 })
          .padding(24)
          .backgroundColor(this.getColors().surface)
          .borderRadius(16)
          .shadow({
            radius: 12,
            color: 'rgba(0,0,0,0.2)',
            offsetX: 0,
            offsetY: 4
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          // 点击背景不关闭
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getColors().background)
  }

  private async handleSetPassword(): Promise<void> {
    if (!this.password) {
      this.passwordError = '请输入密码';
      return;
    }
    if (this.password.length < 4) {
      this.passwordError = '密码至少需要4个字符';
      return;
    }
    if (this.password !== this.confirmPassword) {
      this.passwordError = '两次输入的密码不一致';
      return;
    }

    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.passwordService.initialize(context);
      await this.passwordService.setPassword(this.password);
      this.finishIntro();
    } catch (err) {
      console.error('设置密码失败:', err);
      this.passwordError = '设置密码失败，请重试';
    }
  }

  private finishIntro(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
    } catch (error) {
      console.error('Navigation error:', error);
    }
  }
}
