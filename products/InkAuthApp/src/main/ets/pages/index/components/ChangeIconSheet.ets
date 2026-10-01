import { IconResolver, IconMap } from '../../../core/util/IconResolver';
import { ThemeColors } from '../../../core/util/ThemeManager';
import { IconPack, IconPackEntry } from '../../../core/entity/IconPack';
import { IconPackService } from '../../../core/service/impl/IconPackService';
import { CustomIconService } from '../../../core/service/impl/CustomIconService';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';

@Component
export struct ChangeIconSheet {
  @Watch('onVisibleChanged') @Prop visible: boolean;
  @Prop currentIcon: string | null;
  @Prop colors: ThemeColors;
  onSelect: (iconKey: string | null) => void = () => {};
  onClose: () => void = () => {};
  @State private iconPacks: Array<IconPack> = [];
  @State private selectedPackName: string = 'default';
  @State private searchText: string = '';

  // 获取所有可用图标Key
  private icons: string[] = Array.from(IconMap.keys()).filter(k => k !== 'default').sort();
  private iconPackService: IconPackService = IconPackService.getInstance();
  private customIconService: CustomIconService = CustomIconService.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.loadIconPacks();
  }

  async onVisibleChanged(): Promise<void> {
    if (this.visible) {
      await this.loadIconPacks();
    }
  }

  private async loadIconPacks(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.iconPackService.initialize(context);
      await this.customIconService.initialize(context);
      this.iconPacks = await this.iconPackService.getAll();
      if (this.selectedPackName !== 'default' && !this.iconPacks.some((pack: IconPack): boolean => pack.name === this.selectedPackName)) {
        this.selectedPackName = 'default';
      }
    } catch (error) {
      console.error('加载图标包失败:', error);
    }
  }

  private async pickCustomIcon(): Promise<void> {
    try {
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoViewPicker = new picker.PhotoViewPicker();
      const result = await photoViewPicker.select(photoSelectOptions);
      if (!result || !result.photoUris || result.photoUris.length === 0) {
        return;
      }
      const iconKey = await this.customIconService.createFromImageUri(result.photoUris[0]);
      this.onSelect(iconKey);
    } catch (err) {
      console.error('选择自定义图标失败:', err);
      try {
        this.getUIContext().getPromptAction().showToast({ message: '选择图片失败', duration: 1500 });
      } catch (_e) {
        // ignore
      }
    }
  }

  private filteredDefaultIcons(): string[] {
    const query = this.searchText.toLowerCase().trim();
    if (!query) {
      return this.icons;
    }
    return this.icons.filter((key: string): boolean => key.toLowerCase().includes(query));
  }

  private selectedPackEntries(): Array<IconPackEntry> {
    const pack = this.iconPacks.find((item: IconPack): boolean => item.name === this.selectedPackName);
    if (!pack) {
      return [];
    }
    const query = this.searchText.toLowerCase().trim();
    if (!query) {
      return pack.icons;
    }
    return pack.icons.filter((entry: IconPackEntry): boolean => entry.name.toLowerCase().includes(query));
  }

  build() {
    if (this.visible) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => this.onClose())

        // 底部弹窗
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
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 8 })

          // 标题
          Text('更改图标')
            .fontSize(18)
            .fontWeight(700)
            .fontColor(this.colors.text)
            .margin({ bottom: 16 })
            .textAlign(TextAlign.Center)
            .width('100%')

          TextInput({ placeholder: '搜索图标', text: this.searchText })
            .width('100%')
            .height(40)
            .margin({ left: 16, right: 16, bottom: 10 })
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.colors.background)
            .borderRadius(8)
            .fontColor(this.colors.text)
            .onChange((value: string): void => { this.searchText = value; })

          if (this.iconPacks.length > 0) {
            Scroll() {
              Row({ space: 8 }) {
                this.renderTab('default', '默认')
                ForEach(this.iconPacks, (pack: IconPack) => {
                  this.renderTab(pack.name, pack.name)
                }, (pack: IconPack) => pack.name)
              }
              .padding({ left: 16, right: 16, bottom: 8 })
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }

          // 图标网格
          Grid() {
            if (this.selectedPackName === 'default') {
              // 自定义图标入口
              GridItem() {
                Column() {
                  Image($r('app.media.baseline_image_24'))
                    .width(40)
                    .height(40)
                    .fillColor(this.colors.onSurface)
                    .margin({ bottom: 8 })
                    .padding(8)
                    .backgroundColor(this.colors.background)
                    .borderRadius(8)
                  Text('自定义')
                    .fontSize(12)
                    .fontColor(this.colors.text)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Center)
                .onClick(() => this.pickCustomIcon())
              }

              // 默认图标选项
              GridItem() {
                Column() {
                  Image($r('app.media.baseline_person_24'))
                    .width(40)
                    .height(40)
                    .fillColor(this.colors.onSurface)
                    .margin({ bottom: 8 })
                    .padding(8)
                    .backgroundColor(this.currentIcon === null ? this.colors.primary : 'transparent')
                    .borderRadius(8)
                  Text('默认')
                    .fontSize(12)
                    .fontColor(this.colors.text)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Center)
                .onClick(() => this.onSelect(null))
              }

              // 预设图标
              ForEach(this.filteredDefaultIcons(), (key: string) => {
                GridItem() {
                  this.renderIconItem(IconResolver.getService(key), key, key)
                }
              }, (key: string) => key)
            } else {
              ForEach(this.selectedPackEntries(), (entry: IconPackEntry) => {
                GridItem() {
                  this.renderIconItem(entry.dataUri, entry.name, IconPackService.toIconKey(entry.iconPackName, entry.name))
                }
              }, (entry: IconPackEntry) => entry.name)
            }
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .rowsGap(16)
          .columnsGap(16)
          .padding(16)
          .width('100%')
          .height(350)
        }
        .width('100%')
        .backgroundColor(this.colors.surface)
        .borderRadius({ topLeft: 24, topRight: 24 })
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Bottom)
      .zIndex(100)
    }
  }

  @Builder
  private renderTab(packName: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.selectedPackName === packName ? '#FFFFFF' : this.colors.text)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.selectedPackName === packName ? this.colors.primary : this.colors.background)
      .borderRadius(14)
      .onClick((): void => { this.selectedPackName = packName; })
  }

  @Builder
  private renderIconItem(source: ResourceStr, label: string, iconKey: string | null) {
    Column() {
      Stack() {
        Image(source)
          .width(26)
          .height(26)
          .objectFit(ImageFit.Contain)
      }
      .width(40)
      .height(40)
      .backgroundColor(this.currentIcon === iconKey ? this.colors.primary : 'transparent')
      .border({ width: 1, color: this.colors.divider })
      .borderRadius(8)
      .alignContent(Alignment.Center)

      Text(label)
        .fontSize(12)
        .fontColor(this.colors.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Center)
    .onClick(() => this.onSelect(iconKey))
  }
}
