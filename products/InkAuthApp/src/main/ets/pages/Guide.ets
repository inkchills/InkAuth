// Guide.ets - 入门指南页面

import { ThemeManager, ThemeColors } from '../core/util/ThemeManager';

interface GuideCardData {
  icon: Resource;
  title: string;
  summary: string;
}

@Entry
@Component
struct Guide {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  @StorageProp('insetTopPx') insetTopPx: number = 0;

  private cards: GuideCardData[] = [
    {
      icon: $r('app.media.twotone_qr_code_24'),
      title: '扫描二维码',
      summary: '要添加认证器，请扫描应用或服务提供的二维码。它将被添加到列表中并自动生成新代码。您也可以手动输入详细信息。'
    },
    {
      icon: $r('app.media.twotone_timer_24'),
      title: '使用验证码登录',
      summary: '登录时，使用 InkAuth 提供的唯一代码。它只在短时间内有效。点击列表中的认证器即可将代码复制到剪贴板。'
    },
    {
      icon: $r('app.media.twotone_edit_24'),
      title: '自定义与编辑',
      summary: '重命名和自定义您的认证器以便轻松找到它们。只需点击条目上的菜单图标并按照步骤操作即可。'
    },
    {
      icon: $r('app.media.baseline_sort_24'),
      title: '分类与排序',
      summary: '您可以将认证器整理到不同的分类中以便轻松查找。此外，长按并拖动项目可以按您喜欢的任何顺序重新排列。'
    },
    {
      icon: $r('app.media.twotone_save_24'),
      title: '创建备份',
      summary: '更换设备时不要被锁定在账户之外。创建备份文件并将其存储在安全的地方。备份可以随时恢复并可以用密码保护。'
    }
    // 配套手表应用卡片暂时隐藏：华为手表端暂不具备开发条件
  ];

  getColors(): ThemeColors {
    return this.themeManager.getColors();
  }

  build() {
    Column() {
      // 顶部工具栏
      Row() {
        Image($r('app.media.baseline_arrow_back_24'))
          .width(24)
          .height(24)
          .fillColor(this.getColors().text)
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
          .margin({ right: 16 })

        Text('入门指南')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getColors().text)
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      // 卡片列表
      Scroll() {
        Column() {
          ForEach(this.cards, (card: GuideCardData, index: number) => {
            Column() {
              Row() {
                Image(card.icon)
                  .width(32)
                  .height(32)
                  .fillColor(this.getColors().primary)
                  .margin({ right: 16 })

                Column() {
                  Text(card.title)
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.getColors().text)
                    .margin({ bottom: 6 })

                  Text(card.summary)
                    .fontSize(14)
                    .fontColor(this.getColors().textSecondary)
                    .lineHeight(22)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }
            .width('100%')
            .padding(20)
            .margin({ left: 16, right: 16, bottom: 12 })
            .backgroundColor(this.getColors().surface)
            .borderRadius(12)
            .shadow({
              radius: 4,
              color: 'rgba(0,0,0,0.08)',
              offsetX: 0,
              offsetY: 2
            })
          }, (card: GuideCardData, index: number): string => index.toString())
        }
        .width('100%')
        .padding({ top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ top: px2vp(this.insetTopPx) > 1 ? px2vp(this.insetTopPx) : 36 })
    .backgroundColor(this.getColors().background)
  }
}
