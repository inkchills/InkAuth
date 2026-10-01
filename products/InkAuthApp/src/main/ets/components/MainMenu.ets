// MainMenu.ets

import { ErrorHandler } from '../core/util/ErrorHandler';
import { Category } from '../core/entity/Category';
import { ThemeColors } from '../core/util/ThemeManager';

const UNCATEGORIZED_CATEGORY_ID: string = '__uncategorized__';

@Component
export struct MainMenu {
  @Prop visible: boolean;
  @Prop categories: Array<Category> = [];
  @Prop selectedCategoryId: string | null = null;
  @Prop showUncategorized: boolean = true;
  @Prop colors: ThemeColors;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;
  onSelectCategory: (id: string | null) => void = () => {};
  onManageCategories: () => void = () => {};
  onIconPacksClick: () => void = () => {};
  onBackupClick: () => void = () => {};
  onSettingsClick: () => void = () => {};
  onAboutClick: () => void = () => {};
  onClose: () => void = () => {};
  private errorHandler: ErrorHandler = ErrorHandler.getInstance();

  build() {
    if (this.visible) {
      Stack() {
        // 背景遮罩
        Column() {
          Text('')
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              try {
                this.onClose();
              } catch (error) {
                this.errorHandler.handleError(error as Error, 'MainMenu Background Click');
              }
            })
        }
        .width('100%')
        .height('100%')

        // 菜单内容
        Column() {
          // 顶部指示器
          Row() {
            Text('')
              .width(40)
              .height(4)
              .backgroundColor(this.colors.divider)
              .borderRadius(2)
          }
          .width('100%')
          .height(20)
          .justifyContent(FlexAlign.Center)

          Text($r('app.string.main_menu'))
            .fontSize(18)
            .fontWeight(700)
            .fontColor(this.colors.text)
            .margin({ top: 16, left: 16, right: 16, bottom: 16 })
            .textAlign(TextAlign.Center)

          Text($r('app.string.categories'))
            .fontSize(14)
            .fontColor(this.colors.textSecondary)
            .margin({ left: 16, right: 16, bottom: 8 })
            .textAlign(TextAlign.Start)

          // 全部分类选项
          Column() {
            Row() {
              Text($r('app.string.all'))
                .fontSize(16)
                .fontColor(this.colors.text)
                .flexGrow(1)
              if (this.selectedCategoryId === null) {
                Image($r('app.media.baseline_done_24'))
                  .width(20)
                  .height(20)
                  .fillColor(this.colors.primary)
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center)
            .backgroundColor(this.selectedCategoryId === null ? '#1A' + this.colors.primary.substring(1) : 'transparent') // 10% opacity roughly
            .onClick(() => this.onSelectCategory(null))

            if (this.showUncategorized) {
              Row() {
                Text($r('app.string.uncategorized'))
                  .fontSize(16)
                  .fontColor(this.colors.text)
                  .flexGrow(1)
                if (this.selectedCategoryId === UNCATEGORIZED_CATEGORY_ID) {
                  Image($r('app.media.baseline_done_24'))
                    .width(20)
                    .height(20)
                    .fillColor(this.colors.primary)
                }
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)
              .backgroundColor(this.selectedCategoryId === UNCATEGORIZED_CATEGORY_ID ? '#1A' + this.colors.primary.substring(1) : 'transparent')
              .onClick(() => this.onSelectCategory(UNCATEGORIZED_CATEGORY_ID))
            }

            ForEach(this.categories, (category: Category) => {
              Row() {
                Text(category.name)
                  .fontSize(16)
                  .fontColor(this.colors.text)
                  .flexGrow(1)
                if (this.selectedCategoryId === category.id) {
                  Image($r('app.media.baseline_done_24'))
                    .width(20)
                    .height(20)
                    .fillColor(this.colors.primary)
                }
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)
              .backgroundColor(this.selectedCategoryId === category.id ? '#1A' + this.colors.primary.substring(1) : 'transparent')
              .onClick(() => this.onSelectCategory(category.id))
            }, (category: Category) => category.id)
          }

          Text($r('app.string.more'))
            .fontSize(14)
            .fontColor(this.colors.textSecondary)
            .margin({ left: 16, right: 16, top: 16, bottom: 8 })
            .textAlign(TextAlign.Start)

          // 备份
          Row() {
            Image($r('app.media.baseline_save_24'))
              .width(24)
              .height(24)
              .fillColor(this.colors.textSecondary)
              .margin({ right: 12 })
            Text($r('app.string.backup'))
              .fontSize(16)
              .fontColor(this.colors.text)
              .flexGrow(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            try { this.onBackupClick(); } catch (error) { this.errorHandler.handleError(error as Error, 'MainMenu Backup'); }
          })

          // 分隔线
          Row() {
            Text('').flexGrow(1).height(1).backgroundColor(this.colors.divider)
          }.width('100%').padding({ left: 16, right: 16 })

          // 管理分类
          Row() {
            Image($r('app.media.baseline_category_24'))
              .width(24)
              .height(24)
              .fillColor(this.colors.textSecondary)
              .margin({ right: 12 })
            Text($r('app.string.manage_categories'))
              .fontSize(16)
              .fontColor(this.colors.text)
              .flexGrow(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            try { this.onManageCategories(); } catch (error) { this.errorHandler.handleError(error as Error, 'MainMenu Categories'); }
          })

          // 分隔线
          Row() {
            Text('').flexGrow(1).height(1).backgroundColor(this.colors.divider)
          }.width('100%').padding({ left: 16, right: 16 })

          // 图标包
          Row() {
            Image($r('app.media.baseline_folder_24'))
              .width(24)
              .height(24)
              .fillColor(this.colors.textSecondary)
              .margin({ right: 12 })
            Text($r('app.string.icon_packs'))
              .fontSize(16)
              .fontColor(this.colors.text)
              .flexGrow(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            try { this.onIconPacksClick(); } catch (error) { this.errorHandler.handleError(error as Error, 'MainMenu Icon Packs'); }
          })

          // 分隔线
          Row() {
            Text('').flexGrow(1).height(1).backgroundColor(this.colors.divider)
          }.width('100%').padding({ left: 16, right: 16 })

          // 设置
          Row() {
            Image($r('app.media.baseline_settings_24'))
              .width(24)
              .height(24)
              .fillColor(this.colors.textSecondary)
              .margin({ right: 12 })
            Text($r('app.string.settings'))
              .fontSize(16)
              .fontColor(this.colors.text)
              .flexGrow(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            try { this.onSettingsClick(); } catch (error) { this.errorHandler.handleError(error as Error, 'MainMenu Settings'); }
          })

          // 分隔线
          Row() {
            Text('').flexGrow(1).height(1).backgroundColor(this.colors.divider)
          }.width('100%').padding({ left: 16, right: 16 })

          // 关于
          Row() {
            Image($r('app.media.outline_info_24'))
              .width(24)
              .height(24)
              .fillColor(this.colors.textSecondary)
              .margin({ right: 12 })
            Text($r('app.string.about'))
              .fontSize(16)
              .fontColor(this.colors.text)
              .flexGrow(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16, bottom: 16 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            try { this.onAboutClick(); } catch (error) { this.errorHandler.handleError(error as Error, 'MainMenu About'); }
          })

          // Force sheet background down to the physical bottom.
          Blank()
            .width('100%')
            .height(px2vp(this.insetBottomPx) > 1 ? px2vp(this.insetBottomPx) : 28)
        }
        .width('100%')
        .backgroundColor(this.colors.surface)
        .borderRadius({ topLeft: 20, topRight: 20 })

      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Bottom)
    }
  }
}
