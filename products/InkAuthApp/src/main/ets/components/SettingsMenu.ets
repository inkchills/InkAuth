// SettingsMenu.ets

import { ThemeManager, ThemeMode } from '../core/util/ThemeManager';

@Component
export struct SettingsMenu {
  @Prop visible: boolean;
  onBack: () => void = () => {};
  onCheckUpdates: () => void = () => {};
  private themeManager: ThemeManager = ThemeManager.getInstance();
  @State private isDarkMode: boolean = false;

  aboutToAppear() {
    this.isDarkMode = this.themeManager.isDarkLike();
  }

  build() {
    if (this.visible) {
      Column() {
        Column() {
          Row() {
            Image($r('app.media.baseline_arrow_back_24'))
              .width(24).height(24)
              .onClick(() => this.onBack())
            Text('设置')
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

          Scroll() {
            Column() {
              Text('安全')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ left: 16, right: 16, top: 16, bottom: 8 })
                .textAlign(TextAlign.Start)

              Row() {
                Text('自动锁定')
                  .fontSize(16)
                  .flexGrow(1)
                Toggle({ type: ToggleType.Switch, isOn: false })
                  .width(50)
                  .height(30)
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)

              Row() {
                Text('生物识别解锁')
                  .fontSize(16)
                  .flexGrow(1)
                Toggle({ type: ToggleType.Switch, isOn: false })
                  .width(50)
                  .height(30)
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)

              Text('界面')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ left: 16, right: 16, top: 16, bottom: 8 })
                .textAlign(TextAlign.Start)

              Row() {
                Text('暗色模式')
                  .fontSize(16)
                  .flexGrow(1)
                Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
                  .width(50)
                  .height(30)
                  .onChange((isOn: boolean) => {
                    this.isDarkMode = isOn;
                    this.themeManager.setTheme(isOn ? ThemeMode.DARK : ThemeMode.LIGHT);
                  })
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)

              Row() {
                Text('显示剩余时间')
                  .fontSize(16)
                  .flexGrow(1)
                Toggle({ type: ToggleType.Switch, isOn: false })
                  .width(50)
                  .height(30)
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)

              Text('其他')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ left: 16, right: 16, top: 16, bottom: 8 })
                .textAlign(TextAlign.Start)

              Row() {
                Text('检查更新')
                  .fontSize(16)
                  .flexGrow(1)
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => this.onCheckUpdates())
            }
          }
          .width('100%')
          .flexGrow(1)
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
