import { common } from '@kit.AbilityKit';
import { Want } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { UriBytesReader } from '../core/util/UriBytesReader';
import { IconPack } from '../core/entity/IconPack';
import { IconPackService } from '../core/service/impl/IconPackService';
import { ThemeColors, ThemeManager } from '../core/util/ThemeManager';

const ICON_PACKS_URL: string = 'https://stratumauth.com/icon-packs';

@Entry
@Component
struct IconPacks {
  private iconPackService: IconPackService = IconPackService.getInstance();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  @State private packs: Array<IconPack> = [];
  @State private isLoading: boolean = false;
  @State private deletingPackName: string = '';
  @StorageProp('insetTopPx') insetTopPx: number = 0;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await this.iconPackService.initialize(context);
    await this.loadPacks();
  }

  private getColors(): ThemeColors {
    return this.themeManager.getColors();
  }

  private async loadPacks(): Promise<void> {
    this.packs = await this.iconPackService.getAll();
  }

  private async importIconPack(): Promise<void> {
    try {
      this.isLoading = true;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['InkAuth icon pack|.iconpack,.stratumicons,.icons', 'All files|.*'];
      const uris = await documentViewPicker.select(options);
      if (!uris || uris.length === 0) {
        return;
      }

      const bytes = await this.readFileBytesFromUri(uris[0]);
      const pack = await this.iconPackService.importPackFromBytes(bytes);
      await this.loadPacks();
      this.showToast(`从图标包中导入了 ${pack.icons.length} 个图标。`);
    } catch (error) {
      console.error('导入图标包失败:', error);
      this.showToast(error instanceof Error ? error.message : '图标包导入失败');
    } finally {
      this.isLoading = false;
    }
  }

  private async deletePack(packName: string): Promise<void> {
    try {
      await this.iconPackService.deletePack(packName);
      this.deletingPackName = '';
      await this.loadPacks();
      this.showToast('图标包已删除');
    } catch (error) {
      console.error('删除图标包失败:', error);
      this.showToast('删除图标包失败');
    }
  }

  private showSource(pack: IconPack): void {
    if (!pack.url) {
      this.showToast('这个图标包没有来源链接');
      return;
    }
    this.openUrl(pack.url);
  }

  private async openDownloadPage(): Promise<void> {
    await this.openUrl(ICON_PACKS_URL);
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
      console.error('打开链接失败:', err);
      this.showToast(url);
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 2000 });
    } catch (_error) {}
  }

  private async readFileBytesFromUri(uri: string): Promise<Uint8Array> {
    return UriBytesReader.read(uri);
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Image($r('app.media.baseline_arrow_back_24'))
            .width(28)
            .height(28)
            .fillColor(this.getColors().text)
            .margin({ right: 16 })
            .onClick((): void => { this.getUIContext().getRouter().back(); })
          Text($r('app.string.icon_packs'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getColors().text)
            .layoutWeight(1)
          Button() {
            Image($r('app.media.baseline_add_24'))
              .width(24)
              .height(24)
              .fillColor('#FFFFFF')
          }
          .width(48)
          .height(40)
          .backgroundColor(this.getColors().primary)
          .borderRadius(20)
          .onClick((): void => { this.importIconPack(); })
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: (px2vp(this.insetTopPx) > 1 ? px2vp(this.insetTopPx) : 36) + 8,
          bottom: 20
        })
        .alignItems(VerticalAlign.Center)

        if (this.packs.length === 0) {
          Column() {
            Image($r('app.media.baseline_folder_24'))
              .width(64)
              .height(64)
              .fillColor(this.getColors().textSecondary)
              .margin({ bottom: 18 })
            Text('没有图标包')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getColors().text)
              .margin({ bottom: 8 })
            Text('还没有导入任何图标包')
              .fontSize(14)
              .fontColor(this.getColors().textSecondary)
              .textAlign(TextAlign.Center)
              .margin({ bottom: 8 })
            Text('从官网下载 .iconpack（PNG protobuf），导入后即可使用')
              .fontSize(12)
              .fontColor(this.getColors().textSecondary)
              .textAlign(TextAlign.Center)
              .margin({ bottom: 24 })
            Button($r('app.string.import_icon_pack'))
              .height(44)
              .fontSize(16)
              .backgroundColor(this.getColors().primary)
              .fontColor('#FFFFFF')
              .borderRadius(22)
              .margin({ bottom: 12 })
              .onClick((): void => { this.importIconPack(); })
            Button($r('app.string.get_icon_packs'))
              .height(40)
              .fontSize(14)
              .backgroundColor(this.getColors().surface)
              .fontColor(this.getColors().primary)
              .borderRadius(20)
              .onClick((): void => { this.openDownloadPage(); })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ left: 24, right: 24 })
        } else {
          List({ space: 12 }) {
            ListItem() {
              Row() {
                Text($r('app.string.get_icon_packs'))
                  .fontSize(14)
                  .fontColor(this.getColors().primary)
                  .layoutWeight(1)
                Text('›')
                  .fontSize(16)
                  .fontColor(this.getColors().primary)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(this.getColors().surface)
              .borderRadius(12)
              .onClick((): void => { this.openDownloadPage(); })
            }

            ForEach(this.packs, (pack: IconPack) => {
              ListItem() {
                Column() {
                  Row() {
                    Image($r('app.media.baseline_folder_24'))
                      .width(30)
                      .height(30)
                      .fillColor(this.getColors().primary)
                      .margin({ right: 14 })
                    Column() {
                      Text(pack.name)
                        .fontSize(17)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.getColors().text)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`${pack.icons.length} 个图标`)
                        .fontSize(13)
                        .fontColor(this.getColors().textSecondary)
                        .margin({ top: 4 })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)

                  if (pack.description) {
                    Text(pack.description)
                      .fontSize(13)
                      .fontColor(this.getColors().textSecondary)
                      .lineHeight(18)
                      .margin({ top: 12 })
                  }

                  Row({ space: 12 }) {
                    Button('来源')
                      .height(34)
                      .fontSize(13)
                      .enabled(!!pack.url)
                      .onClick((): void => { this.showSource(pack); })
                    Button('删除')
                      .height(34)
                      .fontSize(13)
                      .backgroundColor(this.getColors().error)
                      .fontColor('#FFFFFF')
                      .onClick((): void => { this.deletingPackName = pack.name; })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End)
                  .margin({ top: 14 })
                }
                .width('100%')
                .padding(16)
                .backgroundColor(this.getColors().surface)
                .borderRadius(12)
              }
            }, (pack: IconPack) => pack.name)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 20 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getColors().background)

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(44)
            .height(44)
            .color(this.getColors().primary)
          Text('正在导入')
            .fontSize(14)
            .fontColor(this.getColors().text)
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0, 0, 0, 0.35)')
      }

      if (this.deletingPackName) {
        Column() {
          Text('删除图标包')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getColors().text)
            .margin({ bottom: 12 })
          Text('确认删除这一图标包吗？已应用到认证器的图标不会被删除。')
            .fontSize(14)
            .fontColor(this.getColors().textSecondary)
            .lineHeight(20)
            .margin({ bottom: 20 })
          Row({ space: 12 }) {
            Button('取消')
              .layoutWeight(1)
              .height(40)
              .onClick((): void => { this.deletingPackName = ''; })
            Button('删除')
              .layoutWeight(1)
              .height(40)
              .backgroundColor(this.getColors().error)
              .fontColor('#FFFFFF')
              .onClick((): void => { this.deletePack(this.deletingPackName); })
          }
          .width('100%')
        }
        .width('82%')
        .padding(20)
        .backgroundColor(this.getColors().surface)
        .borderRadius(16)
        .align(Alignment.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}