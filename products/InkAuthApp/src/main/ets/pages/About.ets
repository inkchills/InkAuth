// About.ets

import { common, Want } from '@kit.AbilityKit';
import { ThemeManager, ThemeColors } from '../core/util/ThemeManager';

@Entry
@Component
struct About {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  @StorageProp('insetTopPx') insetTopPx: number = 0;

  getColors(): ThemeColors {
    return this.themeManager.getColors();
  }

  private async openUrl(url: string): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: url,
        entities: ['entity.system.browsable']
      };
      await context.startAbility(want);
    } catch (err) {
      console.error('open url failed:', err);
      try {
        this.getUIContext().getPromptAction().showToast({ message: url, duration: 2500 });
      } catch (_e) {
        // ignore
      }
    }
  }

  build() {
    Column() {
      Column() {
        Row() {
          Row() {
            Image($r('app.media.baseline_arrow_back_24'))
              .width(24).height(24)
              .fillColor(this.getColors().onBackground)
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
          Text($r('app.string.about'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getColors().text)
            .layoutWeight(1)
            .margin({ left: 4 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ top: px2vp(this.insetTopPx) > 1 ? px2vp(this.insetTopPx) : 36 })
      .backgroundColor(this.getColors().background)

      Scroll() {
        Column() {
          Column() {
            Image(ThemeManager.isDarkColorSet(this.getColors()) ? $r('app.media.big_ic_logo_dark') : $r('app.media.big_ic_logo'))
              .width(80).height(80)
              .margin({ bottom: 12 })
            Text('InkAuth')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getColors().text)
            Text('v1.0.0')
              .fontSize(13)
              .fontColor(this.getColors().textSecondary)
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 8, bottom: 24 })

          Text($r('app.string.about_summary'))
            .fontSize(14)
            .fontColor(this.getColors().text)
            .lineHeight(22)
            .textAlign(TextAlign.Center)
            .margin({ bottom: 12, left: 20, right: 20 })

          Text($r('app.string.about_attribution'))
            .fontSize(13)
            .fontColor(this.getColors().textSecondary)
            .lineHeight(20)
            .textAlign(TextAlign.Center)
            .margin({ bottom: 28, left: 20, right: 20 })

          Column({ space: 10 }) {
            this.linkRow($r('app.string.about_link_source'), 'https://github.com/inkchills/InkAuth')
            this.linkRow($r('app.string.about_link_upstream'), 'https://github.com/stratumauth/app')
            this.linkRow($r('app.string.about_link_iconpacks'), 'https://stratumauth.com/icon-packs')
            this.linkRow($r('app.string.about_link_license'), 'https://www.gnu.org/licenses/gpl-3.0.html')
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
          .margin({ bottom: 32 })

          Column() {
            Text('Copyright (C) 2022 jmh')
              .fontSize(12)
              .fontColor(this.getColors().textSecondary)
            Text('HarmonyOS port Copyright (C) inkchills')
              .fontSize(12)
              .fontColor(this.getColors().textSecondary)
              .margin({ top: 4 })
            Text('Licensed under GPL-3.0')
              .fontSize(12)
              .fontColor(this.getColors().textSecondary)
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ bottom: 40 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getColors().background)
  }

  @Builder
  private linkRow(title: ResourceStr, url: string) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor(this.getColors().text)
        .layoutWeight(1)
      Text('>')
        .fontSize(18)
        .fontColor(this.getColors().textSecondary)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor(this.getColors().surface)
    .borderRadius(10)
    .onClick(() => { this.openUrl(url); })
  }
}