// SortMenu.ets
import { ThemeColors } from '../core/util/ThemeManager';

@Component
export struct SortMenu {
  @Prop visible: boolean;
  @Prop currentSortOption: string;
  @Prop lockOrdering: boolean = false;
  @Prop colors: ThemeColors;
  onSort: (option: string) => void = () => {};
  onToggleLockOrdering: () => void = () => {};
  onCancel: () => void = () => {};

  @Builder
  sortItem(label: string, optionKey: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor(this.colors.text)
        .flexGrow(1)
      Row() {
        Text('')
          .width(20)
          .height(20)
          .borderRadius(10)
          .backgroundColor(this.currentSortOption === optionKey ? this.colors.primary : 'transparent')
          .borderWidth(this.currentSortOption === optionKey ? 0 : 2)
          .borderColor(this.colors.primary)
          .margin({ right: 4 })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onSort(optionKey))
  }

  build() {
    if (this.visible) {
      Stack() {
        Column() {
          Text('')
            .width('100%')
            .height('100%')
            .backgroundColor('transparent')
            .onClick(() => this.onCancel())
        }
        .width('100%')
        .height('100%')

        Column() {
          this.sortItem('字母顺序 (a至z)', 'alphabetical_asc')
          this.sortItem('字母顺序 (z至a)', 'alphabetical_desc')
          this.sortItem('复制次数 (递减)', 'copy_count_desc')
          this.sortItem('复制次数 (递增)', 'copy_count_asc')
          this.sortItem('自定义', 'custom')

          if (this.currentSortOption === 'custom') {
            Row() {
              Text(this.lockOrdering ? '解锁排序' : '锁定排序')
                .fontSize(15)
                .fontColor(this.colors.primary)
                .flexGrow(1)
            }
            .width('100%')
            .height(44)
            .padding({ left: 16, right: 16 })
            .onClick(() => this.onToggleLockOrdering())
          }
        }
        .width(240)
        .backgroundColor(this.colors.surface)
        .borderRadius(8)
        .shadow({
          color: this.colors.onBackground + '40',
          radius: 8,
          offsetX: 0,
          offsetY: 4
        })
        .position({ top: 48, right: 16 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
