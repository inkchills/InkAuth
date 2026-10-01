// AuthenticatorItem.ets

import { Authenticator } from '../core/entity/Authenticator';
import { AuthenticatorTypeSpecification, GenerationMethod } from '../core/AuthenticatorType';
import { IconResolver } from '../core/util/IconResolver';

/**
 * 认证器项组件
 */
@Component
export struct AuthenticatorItem {
  @Prop auth: Authenticator;
  @Watch('onProgressChange') @Prop progress: number;
  @Prop isDarkMode: boolean;
  @Prop tapToCopy: boolean = true;
  @Prop tapToReveal: boolean = false;
  @Prop tapToRevealDuration: number = 10;
  @Prop skipToNext: boolean = false;
  @Prop codeGroupSize: number = 3;
  @Prop showUsernames: boolean = true;
  @Prop viewMode: string = 'default';
  onItemClick: () => void = () => {};
  onCopyCode: (auth: Authenticator) => void = () => {};
  onIncrementCounter: (auth: Authenticator) => void = () => {};

  @State private lastTimeWindow: number = 0;
  @State private revealed: boolean = false;
  @State private skipWindows: number = 0;
  private revealTimerId: number | null = null;

  onProgressChange() {
    if (!this.auth) return;
    const period = this.auth.period || 30;
    const currentTimeWindow = Math.floor(Date.now() / 1000 / period);
    
    // 只有当时间窗口发生变化时才重新计算代码
    if (currentTimeWindow !== this.lastTimeWindow) {
      this.lastTimeWindow = currentTimeWindow;
      this.skipWindows = 0;
      this.updateCode();
    }
  }
  onEditClick: () => void = () => {};
  onRefreshClick: () => void = () => {};

  @State code: string = '••••••';

  aboutToDisappear() {
    if (this.revealTimerId !== null) {
      clearTimeout(this.revealTimerId);
      this.revealTimerId = null;
    }
  }

  /**
   * 页面可见时获取一次代码
   */
  aboutToAppear() {
    if (this.auth) {
      const period = this.auth.period || 30;
      this.lastTimeWindow = Math.floor(Date.now() / 1000 / period);
    }
    this.updateCode();
  }

  /**
   * 更新OTP代码
   */
  private async updateCode(): Promise<void> {
    try {
      const code = this.isTimeBased()
        ? await this.auth.getCode(this.currentTimeCounter())
        : await this.auth.getCodeDefault();
      this.code = this.formatCode(code);
    } catch (error) {
      // 保持占位符
      this.code = '••••••';
    }
  }

  /**
   * 将代码按设置分组（例如 123456 -> 123 456）
   */
  private formatCode(code: string | number): string {
    const s = String(code);
    if (this.codeGroupSize <= 0) {
      return s;
    }

    const groups: string[] = [];
    for (let i = 0; i < s.length; i += this.codeGroupSize) {
      groups.push(s.substring(i, i + this.codeGroupSize));
    }
    return groups.join(' ');
  }

  private hiddenCode(): string {
    const digitCount = this.auth.digits || 6;
    const raw = '•'.repeat(digitCount);
    return this.formatCode(raw);
  }

  private isCounterBased(): boolean {
    return AuthenticatorTypeSpecification.getGenerationMethod(this.auth.type) === GenerationMethod.Counter;
  }

  private isTimeBased(): boolean {
    return AuthenticatorTypeSpecification.getGenerationMethod(this.auth.type) === GenerationMethod.Time;
  }

  private currentTimeCounter(): number {
    const period = this.auth.period || 30;
    const now = Math.floor(Date.now() / 1000);
    return now - (now % period) + this.skipWindows * period;
  }

  private canSkipToNext(): boolean {
    return this.skipToNext && this.isTimeBased() && this.progress <= 33 && this.skipWindows === 0;
  }

  private skipToNextCode(): void {
    this.skipWindows = 1;
    if (this.tapToReveal) {
      this.revealTemporarily();
    }
    this.updateCode();
  }

  private revealTemporarily(): void {
    this.revealed = true;
    if (this.revealTimerId !== null) {
      clearTimeout(this.revealTimerId);
    }
    this.revealTimerId = setTimeout((): void => {
      this.revealed = false;
      this.revealTimerId = null;
    }, Math.max(1, this.tapToRevealDuration) * 1000);
  }

  private handlePrimaryClick(): void {
    if (this.tapToReveal) {
      this.revealTemporarily();
    }

    if (this.tapToCopy) {
      this.onCopyCode(this.auth);
    }

    this.onItemClick && this.onItemClick();
  }

  private isCompact(): boolean {
    return this.viewMode === 'compact';
  }

  private isTile(): boolean {
    return this.viewMode === 'tile';
  }

  private itemPadding(): number {
    return this.isCompact() ? 12 : 18;
  }

  private iconSize(): number {
    return this.isCompact() ? 28 : (this.isTile() ? 28 : 32);
  }

  private titleFontSize(): number {
    return this.isCompact() ? 15 : 18;
  }

  private subtitleFontSize(): number {
    return this.isCompact() ? 13 : 14;
  }

  private codeFontSize(): number {
    return this.isCompact() ? 24 : (this.isTile() ? 24 : 28);
  }

  private contentLeftPadding(): number {
    return this.isCompact() ? 18 : 16;
  }

  private codeLeftInset(): number {
    return this.iconSize() + 12;
  }

  private cardHeight(): number {
    return this.isCompact() ? 94 : (this.isTile() ? 90 : 118);
  }

  /**
   * 构建组件
   */
  build() {
    Column() {
      Column() {
        Column() {
          Row() {
            Row() {
              Image(IconResolver.getService(this.auth.icon))
                .width(this.iconSize())
                .height(this.iconSize())
                .objectFit(ImageFit.Contain)
                .margin({ right: 12 })

              Column() {
                if (this.auth.issuer && this.auth.username && this.showUsernames) {
                  Text(this.auth.issuer)
                    .fontSize(this.titleFontSize())
                    .fontWeight(500)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor(this.isDarkMode ? '#F5F7FA' : '#171A20')
                  Text(this.auth.username)
                    .fontSize(this.subtitleFontSize())
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor(this.isDarkMode ? '#C8CDD6' : '#454B55')
                } else if (this.auth.issuer) {
                  Text(this.auth.issuer)
                    .fontSize(this.titleFontSize())
                    .fontWeight(500)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor(this.isDarkMode ? '#F5F7FA' : '#171A20')
                } else if (this.auth.username) {
                  Text(this.auth.username)
                    .fontSize(this.titleFontSize())
                    .fontWeight(500)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor(this.isDarkMode ? '#F5F7FA' : '#171A20')
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .alignItems(VerticalAlign.Center)

            Image($r('app.media.baseline_more_vert_24'))
              .width(28)
              .height(28)
              .fillColor(this.isDarkMode ? '#F5F7FA' : '#171A20')
              .margin({ top: this.isCompact() ? 2 : 4 })
              .onClick(() => this.onEditClick())
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: this.contentLeftPadding(), right: 12, top: this.isCompact() ? 10 : 12 })

          Row() {
            Blank()
              .width(this.codeLeftInset())

            Text(this.tapToReveal && !this.revealed ? this.hiddenCode() : this.code)
              .fontSize(this.codeFontSize())
              .fontWeight(500)
              .letterSpacing(0)
              .maxLines(1)
              .fontColor(this.isDarkMode ? '#FFFFFF' : '#171A20')
              .layoutWeight(1)

            if (this.isCounterBased() || this.canSkipToNext()) {
              Button() {
                Image($r('app.media.baseline_refresh_24'))
                  .width(22)
                  .height(22)
                  .fillColor(this.isDarkMode ? '#FFFFFF' : '#171A20')
              }
              .width(40)
              .height(32)
              .backgroundColor(this.isDarkMode ? '#35404A' : '#E4EDF6')
              .borderRadius(16)
              .margin({ left: 8 })
              .onClick((): void => {
                if (this.isCounterBased()) {
                  this.onIncrementCounter(this.auth);
                } else {
                  this.skipToNextCode();
                }
              })
            } else {
              Blank()
                .width(40)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: this.contentLeftPadding(), right: 12, top: this.isCompact() ? 2 : 4, bottom: this.isCompact() ? 8 : 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%')
      .layoutWeight(1)

      if (!this.isCounterBased() && !this.canSkipToNext()) {
        Progress({ value: this.progress, total: 100, type: 0 })
          .width('100%')
          .height(4)
          .backgroundColor('#D4E0EA')
          .color('#0A7890')
          .borderRadius(0)
      }
    }
      .height(this.cardHeight())
      .backgroundColor(this.isDarkMode ? '#222A31' : '#EFF6FF')
      .borderRadius(12)
      .width('100%')
      .shadow({
        color: this.isDarkMode ? '#00000066' : '#1A2B3D22',
        radius: 6,
        offsetX: 0,
        offsetY: 2
      })
      .onClick(() => {
        this.handlePrimaryClick();
      })
  }
}
