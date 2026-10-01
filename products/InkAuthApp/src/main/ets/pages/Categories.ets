// Categories.ets — category CRUD, default, assign entries, drag reorder

import { common } from '@kit.AbilityKit';
import { Category } from '../core/entity/Category';
import { Authenticator } from '../core/entity/Authenticator';
import { CategoryService } from '../core/service/impl/CategoryService';
import { AuthenticatorService } from '../core/service/impl/AuthenticatorService';
import { ThemeManager, ThemeColors } from '../core/util/ThemeManager';
import { IconResolver } from '../core/util/IconResolver';

interface AssignEntryItem {
  auth: Authenticator;
  selected: boolean;
  label: string;
}

@Entry
@Component
struct Categories {
  private categoryService: CategoryService = CategoryService.getInstance();
  private authenticatorService: AuthenticatorService = AuthenticatorService.getInstance();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  @StorageProp('insetTopPx') insetTopPx: number = 0;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;
  @State private categories: Array<Category> = [];
  @State private defaultCategoryId: string | null = null;
  @State private showAddDialog: boolean = false;
  @State private showEditDialog: boolean = false;
  @State private showDeleteDialog: boolean = false;
  @State private showAssignSheet: boolean = false;
  @State private showActionMenu: boolean = false;
  @State private editingCategory: Category | null = null;
  @State private categoryName: string = '';
  @State private assignItems: Array<AssignEntryItem> = [];

  getColors(): ThemeColors {
    return this.themeManager.getColors();
  }

  async aboutToAppear(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.categoryService.initialize(context);
      await this.authenticatorService.initialize(context);
    } catch (err) {
      console.error('分类页初始化失败:', err);
    }
    await this.loadCategories();
  }

  async loadCategories(): Promise<void> {
    try {
      this.categories = await this.categoryService.getAll();
      this.defaultCategoryId = await this.categoryService.getDefaultCategory();
    } catch (error) {
      console.error('加载分类失败:', error);
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 1500 });
    } catch (_e) {
      // ignore
    }
  }

  async handleAddCategory(): Promise<void> {
    if (!this.categoryName.trim()) {
      this.toast('分类名称不能为空');
      return;
    }
    try {
      await this.categoryService.create(new Category(this.categoryName.trim()));
      await this.loadCategories();
      this.showAddDialog = false;
      this.categoryName = '';
      this.toast('分类添加成功');
    } catch (error) {
      this.toast((error as Error).message || '添加分类失败');
    }
  }

  async handleEditCategory(): Promise<void> {
    if (!this.categoryName.trim() || !this.editingCategory) {
      this.toast('分类名称不能为空');
      return;
    }
    try {
      const updated = new Category(this.categoryName.trim(), this.editingCategory.id, this.editingCategory.ranking);
      await this.categoryService.update(updated);
      await this.loadCategories();
      this.showEditDialog = false;
      this.editingCategory = null;
      this.categoryName = '';
      this.toast('分类更新成功');
    } catch (error) {
      this.toast((error as Error).message || '更新分类失败');
    }
  }

  async handleDeleteCategory(): Promise<void> {
    if (!this.editingCategory) {
      return;
    }
    try {
      await this.categoryService.delete(this.editingCategory.id);
      await this.loadCategories();
      this.showDeleteDialog = false;
      this.editingCategory = null;
      this.toast('分类删除成功');
    } catch (error) {
      this.toast((error as Error).message || '删除分类失败');
    }
  }

  private openActionMenu(category: Category): void {
    this.editingCategory = category;
    this.showActionMenu = true;
  }

  private async toggleDefault(): Promise<void> {
    if (!this.editingCategory) {
      return;
    }
    const id = this.editingCategory.id;
    const next = this.defaultCategoryId === id ? null : id;
    await this.categoryService.setDefaultCategory(next);
    this.defaultCategoryId = next;
    this.showActionMenu = false;
    this.toast(next ? '已设为默认分类' : '已取消默认分类');
  }

  private async openAssignSheet(): Promise<void> {
    if (!this.editingCategory) {
      return;
    }
    this.showActionMenu = false;
    const all = await this.authenticatorService.getAll();
    const categoryId = this.editingCategory.id;
    const issuerCount = new Map<string, number>();
    for (const auth of all) {
      const key = auth.issuer || '';
      issuerCount.set(key, (issuerCount.get(key) || 0) + 1);
    }

    this.assignItems = all.map((auth: Authenticator): AssignEntryItem => {
      const unique = (issuerCount.get(auth.issuer || '') || 0) === 1;
      const label = (!unique && auth.username)
        ? `${auth.issuer} (${auth.username})`
        : (auth.issuer || '未命名');
      return {
        auth: auth,
        selected: auth.categoryId === categoryId,
        label: label
      };
    });
    this.showAssignSheet = true;
  }

  private async toggleAssign(index: number): Promise<void> {
    if (!this.editingCategory || index < 0 || index >= this.assignItems.length) {
      return;
    }
    const item = this.assignItems[index];
    const nextSelected = !item.selected;
    try {
      await this.categoryService.setAuthenticatorCategory(
        item.auth,
        nextSelected ? this.editingCategory.id : null
      );
      item.selected = nextSelected;
      this.assignItems = [...this.assignItems];
    } catch (err) {
      console.error('分配认证器失败:', err);
      this.toast('更新分类绑定失败');
    }
  }

  private async onCategoryReorder(from: number, to: number): Promise<void> {
    if (from === to || from < 0 || to < 0) {
      return;
    }
    const moved = this.categories.splice(from, 1);
    if (moved.length === 0) {
      return;
    }
    this.categories.splice(to, 0, moved[0]);
    this.categories = [...this.categories];
    const ids = this.categories.map((c: Category): string => c.id);
    try {
      await this.categoryService.reorder(ids);
    } catch (err) {
      console.error('分类重排失败:', err);
    }
  }

  build() {
    Stack() {
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
            Text('分类管理')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getColors().text)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
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

        Text('长按拖拽可调整顺序')
          .fontSize(12)
          .fontColor(this.getColors().textSecondary)
          .margin({ left: 16, bottom: 8 })
          .width('100%')

        if (this.categories.length === 0) {
          Column() {
            Text('暂无分类')
              .fontSize(16)
              .fontColor(this.getColors().textSecondary)
              .margin({ bottom: 12 })
            Text('点击下方按钮添加分类')
              .fontSize(14)
              .fontColor(this.getColors().textSecondary)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.categories, (category: Category) => {
              ListItem() {
                Row() {
                  Column({ space: 4 }) {
                    Text(category.name)
                      .fontSize(16)
                      .fontColor(this.getColors().text)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (this.defaultCategoryId === category.id) {
                      Text('默认分类')
                        .fontSize(12)
                        .fontColor(this.getColors().primary)
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Button('管理')
                    .height(32)
                    .fontSize(12)
                    .onClick(() => this.openActionMenu(category))
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .backgroundColor(this.getColors().surface)
                .borderRadius(10)
              }
              .margin({ left: 16, right: 16, bottom: 10 })
            }, (category: Category) => category.id)
              .onMove((from: number, to: number): void => {
                this.onCategoryReorder(from, to);
              })
          }
          .width('100%')
          .layoutWeight(1)
        }

        Button('添加分类')
          .backgroundColor(this.getColors().primary)
          .fontColor(this.getColors().onPrimary)
          .width('80%')
          .height(44)
          .margin({ top: 12, bottom: 28 })
          .onClick(() => {
            this.categoryName = '';
            this.showAddDialog = true;
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getColors().background)

      if (this.showActionMenu && this.editingCategory) {
        this.buildActionMenu()
      }
      if (this.showAssignSheet && this.editingCategory) {
        this.buildAssignSheet()
      }
      if (this.showAddDialog) {
        this.buildNameDialog('添加分类', (): void => { this.handleAddCategory(); }, (): void => {
          this.showAddDialog = false;
        })
      }
      if (this.showEditDialog) {
        this.buildNameDialog('编辑分类', (): void => { this.handleEditCategory(); }, (): void => {
          this.showEditDialog = false;
        })
      }
      if (this.showDeleteDialog) {
        this.buildDeleteDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildActionMenu() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(() => { this.showActionMenu = false; })

      Column({ space: 0 }) {
        Text(this.editingCategory?.name || '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getColors().text)
          .margin({ bottom: 12 })
          .width('100%')

        this.actionRow('分配认证器', (): void => { this.openAssignSheet(); })
        this.actionRow(this.defaultCategoryId === this.editingCategory?.id ? '取消默认' : '设为默认',
          (): void => { this.toggleDefault(); })
        this.actionRow('重命名', (): void => {
          this.categoryName = this.editingCategory?.name || '';
          this.showActionMenu = false;
          this.showEditDialog = true;
        })
        this.actionRow('删除', (): void => {
          this.showActionMenu = false;
          this.showDeleteDialog = true;
        }, true)
      }
      .width('86%')
      .padding(16)
      .backgroundColor(this.getColors().surface)
      .borderRadius(14)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  private actionRow(label: string, onClick: () => void, danger: boolean = false) {
    Text(label)
      .width('100%')
      .height(46)
      .fontSize(15)
      .fontColor(danger ? '#F44336' : this.getColors().text)
      .textAlign(TextAlign.Start)
      .onClick(onClick)
  }

  @Builder
  private buildAssignSheet() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(() => { this.showAssignSheet = false; })

      Column() {
        Text(`分配到「${this.editingCategory?.name || ''}」`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getColors().text)
          .margin({ bottom: 8 })
          .width('100%')

        Text('点选认证器以加入或移出该分类')
          .fontSize(12)
          .fontColor(this.getColors().textSecondary)
          .margin({ bottom: 12 })
          .width('100%')

        if (this.assignItems.length === 0) {
          Text('暂无认证器')
            .fontSize(14)
            .fontColor(this.getColors().textSecondary)
            .margin({ top: 24, bottom: 24 })
        } else {
          List({ space: 8 }) {
            ForEach(this.assignItems, (item: AssignEntryItem, index: number) => {
              ListItem() {
                Row({ space: 10 }) {
                  Image(IconResolver.getService(item.auth.icon))
                    .width(28)
                    .height(28)
                    .objectFit(ImageFit.Contain)
                  Text(item.label)
                    .fontSize(14)
                    .fontColor(this.getColors().text)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.selected ? '✓' : '')
                    .fontSize(18)
                    .fontColor(this.getColors().primary)
                    .width(24)
                }
                .width('100%')
                .padding(12)
                .backgroundColor(item.selected ? '#1A' + this.getColors().primary.substring(1) : this.getColors().background)
                .borderRadius(8)
                .onClick(() => { this.toggleAssign(index); })
              }
            }, (item: AssignEntryItem, index: number) => `${item.auth.secret}_${index}`)
          }
          .layoutWeight(1)
          .width('100%')
        }

        Button('完成')
          .width('100%')
          .height(42)
          .margin({ top: 12 })
          .onClick(() => { this.showAssignSheet = false; })
      }
      .width('92%')
      .height('70%')
      .padding(16)
      .backgroundColor(this.getColors().surface)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  private buildNameDialog(title: string, onConfirm: () => void, onCancel: () => void) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(onCancel)

      Column() {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getColors().text)
          .margin({ bottom: 16 })
        TextInput({ placeholder: '请输入分类名称', text: this.categoryName })
          .width('100%')
          .height(48)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.getColors().background)
          .borderRadius(8)
          .fontColor(this.getColors().text)
          .onChange((value: string) => { this.categoryName = value; })
          .margin({ bottom: 16 })
        Row() {
          Button('取消')
            .layoutWeight(1)
            .height(40)
            .margin({ right: 10 })
            .onClick(onCancel)
          Button('确定')
            .layoutWeight(1)
            .height(40)
            .onClick(onConfirm)
        }
        .width('100%')
      }
      .width('82%')
      .padding(20)
      .backgroundColor(this.getColors().surface)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  private buildDeleteDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(() => { this.showDeleteDialog = false; })

      Column() {
        Text('确定删除这个分类吗？')
          .fontSize(16)
          .fontColor(this.getColors().text)
          .margin({ bottom: 20 })
        Row() {
          Button('取消')
            .layoutWeight(1)
            .height(40)
            .margin({ right: 10 })
            .onClick(() => { this.showDeleteDialog = false; })
          Button('删除')
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#F44336')
            .onClick(() => { this.handleDeleteCategory(); })
        }
        .width('100%')
      }
      .width('82%')
      .padding(20)
      .backgroundColor(this.getColors().surface)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
