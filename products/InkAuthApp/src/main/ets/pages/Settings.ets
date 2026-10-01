// Settings.ets - 完整设置页面(通用/安全/外观三类)

import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { ThemeManager, ThemeMode, ThemeColors, AccentOption } from '../core/util/ThemeManager';
import { AppLanguage, LanguageManager } from '../core/util/LanguageManager';
import { PasswordService } from '../core/service/impl/PasswordService';
import { AuthenticatorService } from '../core/service/impl/AuthenticatorService';
import preferences from '@ohos.data.preferences';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { picker } from '@kit.CoreFileKit';
import { userAuth } from '@kit.UserAuthenticationKit';

interface TimeoutOption {
  label: string;
  value: number;
}

interface ThemeOption {
  label: string;
  value: string;
}

interface ViewModeOption {
  label: string;
  value: string;
}

interface CodeGroupOption {
  label: string;
  value: number;
}

interface TapRevealOption {
  label: string;
  value: number;
}

interface LanguageOption {
  label: Resource;
  value: AppLanguage;
}

@Entry
@Component
struct Settings {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private languageManager: LanguageManager = LanguageManager.getInstance();
  private passwordService: PasswordService = PasswordService.getInstance();
  private authenticatorService: AuthenticatorService = AuthenticatorService.getInstance();
  private prefs: preferences.Preferences | null = null;

  // --- 通用 ---
  @State backupReminder: boolean = true;
  @State autoBackupEnabled: boolean = false;
  @State tapToCopy: boolean = true;
  @State skipToNext: boolean = false;
  @State showUncategorized: boolean = true;
  @State currentLanguage: AppLanguage = 'system';

  // --- 安全 ---
  @State hasPassword: boolean = false;
  @State dbPasswordBackup: boolean = false;
  @State biometricUnlock: boolean = false;
  @State passwordGateVersion: number = 0;
  @State timeoutSeconds: number = 0;
  @State tapToReveal: boolean = false;
  @State tapToRevealDuration: number = 10;
  @State allowScreenshots: boolean = false;

  // --- 外观 ---
  @State themeMode: string = 'system';
  @State themeLabel: string = '跟随系统';
  @State accentColor: string = 'default';
  @State accentLabel: string = '默认';
  @State viewMode: string = 'default';
  @State codeGroupSize: number = 3;
  @State showUsernames: boolean = true;
  @StorageProp('insetTopPx') insetTopPx: number = 0;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;

  // --- 自动备份设置面板 ---
  @State showAutoBackupSetup: boolean = false;
  @State autoBackupPath: string = '';
  @State autoBackupPassword: string = '';
  @State confirmAutoBackupPassword: string = '';
  @State autoBackupPasswordError: string = '';

  // --- 生物识别 ---
  @State biometricSupported: boolean = false;

  // --- 列表选项对话框 ---
  @State showTimeoutPicker: boolean = false;
  @State showLanguagePicker: boolean = false;
  @State showThemePicker: boolean = false;
  @State showAccentPicker: boolean = false;
  @State showViewModePicker: boolean = false;
  @State showCodeGroupPicker: boolean = false;
  @State showTapRevealDurationPicker: boolean = false;
  @State showPasswordDialog: boolean = false;
  @State newPassword: string = '';
  @State confirmNewPassword: string = '';
  @State passwordError: string = '';
  @State themeColors: ThemeColors = ThemeManager.getInstance().getColors();

  private themeListener: () => void = (): void => {
    // 强制触发 UI 刷新
    this.themeColors = this.themeManager.getColors();
  }

  private timeoutOptions: TimeoutOption[] = [
    { label: '永不', value: 0 },
    { label: '30 秒', value: 30 },
    { label: '1 分钟', value: 60 },
    { label: '2 分钟', value: 120 },
    { label: '5 分钟', value: 300 },
    { label: '10 分钟', value: 600 }
  ];

  private languageOptions: LanguageOption[] = [
    { label: $r('app.string.language_system'), value: 'system' },
    { label: $r('app.string.language_zh'), value: 'zh' },
    { label: $r('app.string.language_en'), value: 'en' }
  ];

  private themeOptions: ThemeOption[] = [
    { label: '跟随系统', value: 'system' },
    { label: '浅色', value: 'light' },
    { label: '深色', value: 'dark' },
    { label: '纯黑', value: 'black' }
  ];

  private accentOptions: AccentOption[] = ThemeManager.ACCENT_OPTIONS;

  private viewModeOptions: ViewModeOption[] = [
    { label: '默认', value: 'default' },
    { label: '紧凑', value: 'compact' },
    { label: '平铺', value: 'tile' }
  ];

  private codeGroupOptions: CodeGroupOption[] = [
    { label: '不分组', value: 0 },
    { label: '2', value: 2 },
    { label: '3', value: 3 },
    { label: '4', value: 4 }
  ];

  private tapRevealDurationOptions: TapRevealOption[] = [
    { label: '5 秒', value: 5 },
    { label: '10 秒', value: 10 },
    { label: '15 秒', value: 15 },
    { label: '30 秒', value: 30 }
  ];

  async aboutToAppear(): Promise<void> {
    this.themeManager.addListener(this.themeListener);
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.passwordService.initialize(context);
      this.hasPassword = this.passwordService.hasPassword();

      const store = await preferences.getPreferences(context, 'settings_prefs');
      this.prefs = store;
      if (!this.languageManager.isInitialized()) {
        await this.languageManager.initialize(context);
      }
      this.currentLanguage = this.languageManager.getLanguage();
      this.backupReminder = (await store.get('backupReminder', true)) as boolean;
      this.autoBackupEnabled = (await store.get('autoBackup', false)) as boolean;
      this.tapToCopy = (await store.get('tapToCopy', true)) as boolean;
      this.skipToNext = (await store.get('skipToNext', false)) as boolean;
      this.showUncategorized = (await store.get('showUncategorized', true)) as boolean;

      this.dbPasswordBackup = (await store.get('dbPasswordBackup', false)) as boolean;
      this.biometricUnlock = (await store.get('biometricUnlock', false)) as boolean;
      this.timeoutSeconds = (await store.get('timeoutSeconds', 0)) as number;
      this.tapToReveal = (await store.get('tapToReveal', false)) as boolean;
      this.tapToRevealDuration = (await store.get('tapToRevealDuration', 10)) as number;
      this.allowScreenshots = (await store.get('allowScreenshots', false)) as boolean;

      const savedTheme = (await store.get('themeMode', 'system')) as string;
      this.themeMode = savedTheme;
      this.themeLabel = this.themeModeToLabel(savedTheme);
      this.applyThemePreference(savedTheme);
      const savedAccent = (await store.get('accentColor', 'default')) as string;
      this.accentColor = savedAccent;
      this.accentLabel = this.accentIdToLabel(savedAccent);
      this.themeManager.setAccentId(savedAccent);
      this.viewMode = (await store.get('viewMode', 'default')) as string;
      this.codeGroupSize = (await store.get('codeGroupSize', 3)) as number;
      this.showUsernames = (await store.get('showUsernames', true)) as boolean;

      // 加载自动备份路径和密码
      this.autoBackupPath = (await store.get('autoBackupPath', '')) as string;
      this.autoBackupPassword = (await store.get('autoBackupPassword', '')) as string;

      // 检测生物识别可用性
      try {
        userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL3);
        this.biometricSupported = true;
      } catch (_e) {
        try {
          userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL3);
          this.biometricSupported = true;
        } catch (_e2) {
          this.biometricSupported = false;
        }
      }

      // 页面加载后应用截图策略
      this.applyScreenshotPolicy(this.allowScreenshots);
      this.themeColors = this.themeManager.getColors();
    } catch (err) {
      console.error('加载设置失败:', err);
    }
  }

  aboutToDisappear() {
    this.themeManager.removeListener(this.themeListener);
  }

  private async savePref(key: string, value: preferences.ValueType): Promise<void> {
    if (this.prefs) {
      await this.prefs.put(key, value);
      await this.prefs.flush();
    }
  }

  private async onLanguageSelected(lang: AppLanguage): Promise<void> {
    this.showLanguagePicker = false;
    if (lang === this.currentLanguage) {
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.languageManager.setLanguage(lang, context);
      this.currentLanguage = lang;
    } catch (err) {
      hilog.error(0xFF00, 'Settings', '切换语言失败: %{public}s', String(err));
    }
  }

  getColors(): ThemeColors {
    return this.themeColors;
  }

  private getTimeoutLabel(): string {
    const opt = this.timeoutOptions.find((o: TimeoutOption): boolean => o.value === this.timeoutSeconds);
    return opt ? opt.label : '永不';
  }

  private getLanguageLabel(): Resource {
    const opt = this.languageOptions.find((o: LanguageOption): boolean => o.value === this.currentLanguage);
    return opt ? opt.label : $r('app.string.language_system');
  }

  private getThemeLabel(): string {
    return this.themeLabel;
  }

  private themeModeToLabel(mode: string): string {
    if (mode === 'light') {
      return '浅色';
    }
    if (mode === 'dark') {
      return '深色';
    }
    if (mode === 'black') {
      return '纯黑';
    }
    return '跟随系统';
  }

  private accentIdToLabel(id: string): string {
    const opt = this.accentOptions.find((o: AccentOption): boolean => o.id === id);
    return opt ? opt.label : '默认';
  }

  private applyThemePreference(mode: string): void {
    if (mode === 'dark') {
      this.themeManager.setTheme(ThemeMode.DARK);
      return;
    }
    if (mode === 'black') {
      this.themeManager.setTheme(ThemeMode.BLACK);
      return;
    }
    if (mode === 'light') {
      this.themeManager.setTheme(ThemeMode.LIGHT);
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const isDark = context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      this.themeManager.setTheme(isDark ? ThemeMode.DARK : ThemeMode.LIGHT);
    } catch (_e) {
      this.themeManager.setTheme(ThemeMode.LIGHT);
    }
  }

  private getViewModeLabel(): string {
    const opt = this.viewModeOptions.find((o: ViewModeOption): boolean => o.value === this.viewMode);
    return opt ? opt.label : '默认';
  }

  private getCodeGroupLabel(): string {
    const opt = this.codeGroupOptions.find((o: CodeGroupOption): boolean => o.value === this.codeGroupSize);
    return opt ? opt.label : '3';
  }

  private getTapRevealDurationLabel(): string {
    const opt = this.tapRevealDurationOptions.find((o: TapRevealOption): boolean => o.value === this.tapToRevealDuration);
    return opt ? opt.label : '10 秒';
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏（含状态栏安全区）
        Column() {
          Row() {
            Image($r('app.media.baseline_arrow_back_24'))
              .width(24).height(24)
              .fillColor(this.getColors().onBackground)
              .margin({ left: 16 })
              .onClick(() => { this.getUIContext().getRouter().back(); })
            Text($r('app.string.settings'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getColors().text)
              .margin({ left: 16 })
          }
          .width('100%')
          .height(56)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({ top: px2vp(this.insetTopPx) })
        .backgroundColor(this.getColors().background)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Scroll() {
          Column({ space: 0 }) {
            // ========== 通用 ==========
            this.sectionHeader($r('app.string.general'))

            this.switchItem($r('app.string.backup_reminder'), '当你的认证器发生更改后提醒备份', this.backupReminder,
              (v: boolean): void => { this.backupReminder = v; this.savePref('backupReminder', v); })

            this.clickItem($r('app.string.auto_backup'), this.autoBackupEnabled ? '已开启 · ' + (this.autoBackupPath || '未选择路径') : '已关闭',
              (): void => {
              this.confirmAutoBackupPassword = '';
              this.autoBackupPasswordError = '';
              this.showAutoBackupSetup = true;
            })

            this.clickItem($r('app.string.language'), this.getLanguageLabel(), (): void => {
              this.showLanguagePicker = true;
            })

            this.switchItem($r('app.string.tap_to_copy'), '点击认证器即可复制验证码', this.tapToCopy,
              (v: boolean): void => { this.tapToCopy = v; this.savePref('tapToCopy', v); })

            this.switchItem($r('app.string.skip_to_next'), '当验证码即将过期时显示刷新按钮，可提前切到下一个验证码', this.skipToNext,
              (v: boolean): void => { this.skipToNext = v; this.savePref('skipToNext', v); })

            this.switchItem($r('app.string.show_uncategorized'), '在分类列表中显示未分类的认证器', this.showUncategorized,
              (v: boolean): void => { this.showUncategorized = v; this.savePref('showUncategorized', v); })

            this.clickItem($r('app.string.reset_copy_count'), '将所有认证器的复制次数清零', (): void => {
              this.resetCopyCounts();
            })

            // ========== 安全 ==========
            this.sectionHeader($r('app.string.security'))

            this.clickItem($r('app.string.password'), '访问应用前要求验证密码（认证器数据已使用系统加密存储保护）', (): void => {
              this.newPassword = '';
              this.confirmNewPassword = '';
              this.passwordError = '';
              this.showPasswordDialog = true;
            })

            this.switchItemWithEnabled('以数据库密码备份', '加密备份时直接使用应用锁密码，无需再输入备份密码', this.dbPasswordBackup,
              (v: boolean): void => {
                this.dbPasswordBackup = v;
                this.savePref('dbPasswordBackup', v);
              }, this.hasPassword)

            if (this.biometricSupported) {
              Row() {
                Column({ space: 2 }) {
                  Text($r('app.string.biometric_unlock'))
                    .fontSize(16)
                    .fontColor(this.hasPassword ? this.getColors().text : this.getColors().textSecondary)
                  Text('使用指纹或面部识别解锁应用')
                    .fontSize(12)
                    .fontColor(this.getColors().textSecondary)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .flexGrow(1)
                .margin({ right: 12 })

                Toggle({ type: ToggleType.Switch, isOn: this.biometricUnlock })
                  .selectedColor(this.getColors().primary)
                  .enabled(this.hasPassword)
                  .onChange((v: boolean): void => {
                    if (!this.hasPassword) return;
                    if (v) {
                      this.verifyBiometricAndEnable();
                    } else {
                      this.biometricUnlock = false;
                      this.savePref('biometricUnlock', false);
                    }
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .alignItems(VerticalAlign.Center)
              .opacity(this.hasPassword ? 1.0 : 0.4)
              .enabled(this.hasPassword)
            }

            this.clickItemWithEnabled($r('app.string.timeout'), this.getTimeoutLabel(), (): void => {
              this.showTimeoutPicker = true;
            }, this.hasPassword)

            this.switchItem($r('app.string.tap_to_reveal'), '隐藏验证码，点击后才显示', this.tapToReveal,
              (v: boolean): void => {
                this.tapToReveal = v;
                this.savePref('tapToReveal', v);
              })

            if (this.tapToReveal) {
              this.clickItem('显示持续时间', this.getTapRevealDurationLabel(), (): void => {
                this.showTapRevealDurationPicker = true;
              })
            }

            this.switchItem($r('app.string.allow_screenshots'), '允许在应用内截取屏幕', this.allowScreenshots,
              (v: boolean): void => {
                this.allowScreenshots = v;
                this.savePref('allowScreenshots', v);
                this.applyScreenshotPolicy(v);
              })

            // ========== 外观 ==========
            this.sectionHeader($r('app.string.appearance'))

            // 主题：直接绑定 @State，避免 @Builder 参数不刷新
            Row() {
              Column({ space: 2 }) {
                Text($r('app.string.theme'))
                  .fontSize(16)
                  .fontColor(this.getColors().text)
                Text(this.themeLabel)
                  .fontSize(12)
                  .fontColor(this.getColors().textSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .flexGrow(1)

              Image($r('app.media.baseline_chevron_right_24'))
                .width(20).height(20)
                .fillColor(this.getColors().textSecondary)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .alignItems(VerticalAlign.Center)
            .onClick((): void => { this.showThemePicker = true; })

            Row() {
              Column({ space: 2 }) {
                Text('强调色')
                  .fontSize(16)
                  .fontColor(this.getColors().text)
                Text(this.accentLabel)
                  .fontSize(12)
                  .fontColor(this.getColors().textSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .flexGrow(1)

              Row() {
                Row()
                  .width(20)
                  .height(20)
                  .borderRadius(10)
                  .backgroundColor(this.getColors().primary)
                  .margin({ right: 8 })
                Image($r('app.media.baseline_chevron_right_24'))
                  .width(20).height(20)
                  .fillColor(this.getColors().textSecondary)
              }
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .alignItems(VerticalAlign.Center)
            .onClick((): void => { this.showAccentPicker = true; })

            this.clickItem($r('app.string.view_mode'), this.getViewModeLabel(), (): void => {
              this.showViewModePicker = true;
            })

            this.clickItem($r('app.string.code_group'), this.getCodeGroupLabel(), (): void => {
              this.showCodeGroupPicker = true;
            })

            this.switchItem($r('app.string.show_usernames'), '在认证器列表中显示用户名', this.showUsernames,
              (v: boolean): void => { this.showUsernames = v; this.savePref('showUsernames', v); })

            // 底部间距（含手势条安全区）
            Row().height(32 + px2vp(this.insetBottomPx))
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getColors().background)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 选项对话框叠加层
      if (this.showTimeoutPicker) {
        this.buildListPicker('自动锁定超时',
          this.timeoutOptions.map((o: TimeoutOption): ResourceStr => o.label),
          this.timeoutOptions.findIndex((o: TimeoutOption): boolean => o.value === this.timeoutSeconds),
          (index: number): void => {
            this.timeoutSeconds = this.timeoutOptions[index].value;
            this.savePref('timeoutSeconds', this.timeoutSeconds);
            this.showTimeoutPicker = false;
          },
          (): void => { this.showTimeoutPicker = false; })
      }

      if (this.showLanguagePicker) {
        this.buildListPicker($r('app.string.language'),
          this.languageOptions.map((o: LanguageOption): ResourceStr => o.label),
          this.languageOptions.findIndex((o: LanguageOption): boolean => o.value === this.currentLanguage),
          (index: number): void => {
            this.onLanguageSelected(this.languageOptions[index].value);
          },
          (): void => { this.showLanguagePicker = false; })
      }

      if (this.showThemePicker) {
        this.buildListPicker($r('app.string.theme'),
          this.themeOptions.map((o: ThemeOption): ResourceStr => o.label),
          this.themeOptions.findIndex((o: ThemeOption): boolean => o.value === this.themeMode),
          (index: number): void => {
            const mode = this.themeOptions[index].value;
            this.themeMode = mode;
            this.themeLabel = this.themeModeToLabel(mode);
            this.savePref('themeMode', mode);
            this.applyThemePreference(mode);
            this.themeColors = this.themeManager.getColors();
            this.showThemePicker = false;
          },
          (): void => { this.showThemePicker = false; })
      }

      if (this.showAccentPicker) {
        this.buildListPicker('强调色',
          this.accentOptions.map((o: AccentOption): ResourceStr => o.label),
          this.accentOptions.findIndex((o: AccentOption): boolean => o.id === this.accentColor),
          (index: number): void => {
            const accent = this.accentOptions[index];
            this.accentColor = accent.id;
            this.accentLabel = accent.label;
            this.savePref('accentColor', accent.id);
            this.themeManager.setAccentId(accent.id);
            this.themeColors = this.themeManager.getColors();
            this.showAccentPicker = false;
          },
          (): void => { this.showAccentPicker = false; })
      }

      if (this.showViewModePicker) {
        this.buildListPicker($r('app.string.view_mode'),
          this.viewModeOptions.map((o: ViewModeOption): ResourceStr => o.label),
          this.viewModeOptions.findIndex((o: ViewModeOption): boolean => o.value === this.viewMode),
          (index: number): void => {
            this.viewMode = this.viewModeOptions[index].value;
            this.savePref('viewMode', this.viewMode);
            this.showViewModePicker = false;
          },
          (): void => { this.showViewModePicker = false; })
      }

      if (this.showCodeGroupPicker) {
        this.buildListPicker($r('app.string.code_group'),
          this.codeGroupOptions.map((o: CodeGroupOption): ResourceStr => o.label),
          this.codeGroupOptions.findIndex((o: CodeGroupOption): boolean => o.value === this.codeGroupSize),
          (index: number): void => {
            this.codeGroupSize = this.codeGroupOptions[index].value;
            this.savePref('codeGroupSize', this.codeGroupSize);
            this.showCodeGroupPicker = false;
          },
          (): void => { this.showCodeGroupPicker = false; })
      }

      if (this.showTapRevealDurationPicker) {
        this.buildListPicker('显示持续时间',
          this.tapRevealDurationOptions.map((o: TapRevealOption): ResourceStr => o.label),
          this.tapRevealDurationOptions.findIndex((o: TapRevealOption): boolean => o.value === this.tapToRevealDuration),
          (index: number): void => {
            this.tapToRevealDuration = this.tapRevealDurationOptions[index].value;
            this.savePref('tapToRevealDuration', this.tapToRevealDuration);
            this.showTapRevealDurationPicker = false;
          },
          (): void => { this.showTapRevealDurationPicker = false; })
      }

      // 密码设置对话框
      if (this.showPasswordDialog) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick((): void => { this.showPasswordDialog = false; })

          Column({ space: 12 }) {
            Text(this.hasPassword ? '更改密码' : '设置密码')
              .fontSize(18)
              .fontWeight(700)
              .fontColor(this.getColors().text)

            TextInput({ placeholder: '输入新密码', text: this.newPassword })
              .type(InputType.Password)
              .width('100%')
              .height(46)
              .borderRadius(8)
              .backgroundColor(this.getColors().surface)
              .fontColor(this.getColors().text)
              .onChange((v: string): void => { this.newPassword = v; this.passwordError = ''; })

            TextInput({ placeholder: '确认新密码', text: this.confirmNewPassword })
              .type(InputType.Password)
              .width('100%')
              .height(46)
              .borderRadius(8)
              .backgroundColor(this.getColors().surface)
              .fontColor(this.getColors().text)
              .onChange((v: string): void => { this.confirmNewPassword = v; this.passwordError = ''; })

            if (this.passwordError) {
              Text(this.passwordError)
                .fontSize(13)
                .fontColor(this.getColors().error)
            }

            Row({ space: 12 }) {
              Button('取消')
                .height(40)
                .backgroundColor(this.getColors().surface)
                .fontColor(this.getColors().text)
                .borderRadius(20)
                .flexGrow(1)
                .onClick((): void => { this.showPasswordDialog = false; })
              Button(this.hasPasswordInput() ? '更新密码' : '清除密码')
                .height(40)
                .backgroundColor(this.getColors().primary)
                .fontColor(this.getColors().onPrimary)
                .borderRadius(20)
                .flexGrow(1)
                .onClick((): void => { this.handlePasswordConfirm(); })
            }
            .width('100%')
          }
          .width('85%')
          .padding(20)
          .backgroundColor(this.getColors().background)
          .borderRadius(16)
          .align(Alignment.Bottom)
          .margin({ bottom: 24 })
        }
        .width('100%')
        .height('100%')
      }

      // 自动备份设置面板
      if (this.showAutoBackupSetup) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.3)')
            .onClick((): void => { this.showAutoBackupSetup = false; })

          Column({ space: 12 }) {
            // 标题
            Row() {
              Text($r('app.string.auto_backup'))
                .fontSize(18)
                .fontWeight(700)
                .fontColor(this.getColors().text)
              Blank().flexGrow(1)
              Image($r('app.media.baseline_close_24'))
                .width(24).height(24)
                .fillColor(this.getColors().onBackground)
                .onClick((): void => { this.showAutoBackupSetup = false; })
            }
            .width('100%')

            // 启用开关
            Row() {
              Text('启用自动备份')
                .fontSize(16)
                .fontColor(this.getColors().text)
                .flexGrow(1)
              Toggle({ type: ToggleType.Switch, isOn: this.autoBackupEnabled })
                .selectedColor(this.getColors().primary)
                .onChange((v: boolean): void => {
                  this.autoBackupEnabled = v;
                  this.savePref('autoBackup', v);
                })
            }
            .width('100%')

            Text('自动备份会在认证器数据发生变化时自动保存备份文件。')
              .fontSize(13)
              .fontColor(this.getColors().textSecondary)

            // 备份路径选择
            Column({ space: 6 }) {
              Text('备份位置')
                .fontSize(14)
                .fontWeight(600)
                .fontColor(this.getColors().text)
                .width('100%')

              Row() {
                Text(this.autoBackupPath || '未选择备份路径')
                  .fontSize(13)
                  .fontColor(this.autoBackupPath ? this.getColors().text : this.getColors().textSecondary)
                  .flexGrow(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Button('选择')
                  .height(32)
                  .fontSize(13)
                  .backgroundColor(this.getColors().primary)
                  .fontColor(this.getColors().onPrimary)
                  .borderRadius(16)
                  .onClick((): void => { this.pickAutoBackupPath(); })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getColors().surface)
            .borderRadius(10)

            // 备份加密密码
            Column({ space: 6 }) {
              Text('加密密码')
                .fontSize(14)
                .fontWeight(600)
                .fontColor(this.getColors().text)
                .width('100%')

              Text('为自动备份文件设置独立的加密密码（与应用密码无关）')
                .fontSize(12)
                .fontColor(this.getColors().textSecondary)
                .width('100%')

              TextInput({ placeholder: '输入备份密码', text: this.autoBackupPassword })
                .type(InputType.Password)
                .width('100%')
                .height(42)
                .borderRadius(8)
                .backgroundColor(this.getColors().surface)
                .fontColor(this.getColors().text)
                .onChange((v: string): void => {
                  this.autoBackupPassword = v;
                  this.autoBackupPasswordError = '';
                })

              TextInput({ placeholder: '确认备份密码', text: this.confirmAutoBackupPassword })
                .type(InputType.Password)
                .width('100%')
                .height(42)
                .borderRadius(8)
                .backgroundColor(this.getColors().surface)
                .fontColor(this.getColors().text)
                .onChange((v: string): void => {
                  this.confirmAutoBackupPassword = v;
                  this.autoBackupPasswordError = '';
                })
            }
            .width('100%')

            if (this.autoBackupPasswordError) {
              Text(this.autoBackupPasswordError)
                .fontSize(13)
                .fontColor(this.getColors().error)
            }

            // 操作按钮
            Row({ space: 12 }) {
              Button('取消')
                .height(40)
                .backgroundColor(this.getColors().surface)
                .fontColor(this.getColors().text)
                .borderRadius(20)
                .flexGrow(1)
                .onClick((): void => { this.showAutoBackupSetup = false; })
              Button('保存')
                .height(40)
                .backgroundColor(this.getColors().primary)
                .fontColor(this.getColors().onPrimary)
                .borderRadius(20)
                .flexGrow(1)
                .onClick((): void => { this.saveAutoBackupSettings(); })
            }
            .width('100%')
          }
          .width('85%')
          .padding(20)
          .backgroundColor(this.getColors().background)
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  private async pickAutoBackupPath(): Promise<void> {
    try {
      if (!canIUse("SystemCapability.FileManagement.UserFileService.FolderSelection")) {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '当前设备不支持文件夹选择', duration: 1500 });
        hilog.warn(0xFF00, 'Settings', '设备不支持 FolderSelection 能力');
        return;
      }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(context);
      const selectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = 1;
      selectOptions.selectMode = picker.DocumentSelectMode.FOLDER;
      const result = await documentPicker.select(selectOptions);
      if (result && result.length > 0) {
        this.autoBackupPath = result[0];
      }
    } catch (err) {
      hilog.error(0xFF00, 'Settings', '选择备份路径失败: %{public}s', String(err));
    }
  }

  private async saveAutoBackupSettings(): Promise<void> {
    // 如果启用了自动备份，验证设置
    if (this.autoBackupEnabled) {
      if (!this.autoBackupPath) {
        this.autoBackupPasswordError = '请选择备份路径';
        return;
      }
      if (this.autoBackupPassword.length > 0 && this.autoBackupPassword.length < 4) {
        this.autoBackupPasswordError = '密码至少需要4个字符';
        return;
      }
      if (this.autoBackupPassword !== this.confirmAutoBackupPassword) {
        this.autoBackupPasswordError = '两次输入的密码不一致';
        return;
      }
    }

    await this.savePref('autoBackup', this.autoBackupEnabled);
    await this.savePref('autoBackupPath', this.autoBackupPath);
    await this.savePref('autoBackupPassword', this.autoBackupPassword);

    this.showAutoBackupSetup = false;
    const prompt = this.getUIContext().getPromptAction();
    prompt.showToast({ message: '自动备份设置已保存', duration: 1500 });
  }

  private verifyBiometricAndEnable(): void {
    hilog.debug(0xFF00, 'Settings', 'verifyBiometricAndEnable: Entering...');
    const authTypes: userAuth.UserAuthType[] = [];
    try {
      // 尝试使用 ATL3 检测，以匹配解锁场景的高安全性要求
      userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL3);
      authTypes.push(userAuth.UserAuthType.FINGERPRINT);
    } catch (e) {
      hilog.debug(0xFF00, 'Settings', '指纹识别(ATL3)不可用: %{public}s', JSON.stringify(e));
    }
    
    // 仅在指纹不可用时尝试人脸，避免混合调用可能导致的问题
    if (authTypes.length === 0) {
      try {
        userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL3);
        authTypes.push(userAuth.UserAuthType.FACE);
      } catch (e) {
        hilog.debug(0xFF00, 'Settings', '面部识别(ATL3)不可用: %{public}s', JSON.stringify(e));
      }
    }

    if (authTypes.length === 0) {
      hilog.warn(0xFF00, 'Settings', 'verifyBiometricAndEnable: No supported biometric types found.');
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '设备不支持符合安全要求的生物识别', duration: 1500 });
      return;
    }

    try {
      hilog.debug(0xFF00, 'Settings', 'verifyBiometricAndEnable: Attempting to start authentication with types: %{public}s', JSON.stringify(authTypes));
      // Challenge 建议至少16字节
      const challenge = new Uint8Array([
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
        0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F
      ]);
      const authParam: userAuth.AuthParam = {
        challenge: challenge,
        authType: authTypes,
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
      };
      
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const widgetParam: userAuth.WidgetParam = {
        title: '验证身份以启用生物识别解锁',
        uiContext: context
      };
      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      userAuthInstance.on('result', {
        onResult: (result: userAuth.UserAuthResult): void => {
          hilog.debug(0xFF00, 'Settings', 'verifyBiometricAndEnable: onResult received. Result code: %{public}d', result.result);
          // 检查是否也是 12500000 (SUCCESS)
          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            this.biometricUnlock = true;
            this.savePref('biometricUnlock', true);
            const prompt = this.getUIContext().getPromptAction();
            prompt.showToast({ message: '生物识别解锁已启用', duration: 1500 });
          } else {
            this.biometricUnlock = false;
            hilog.warn(0xFF00, 'Settings', 'verifyBiometricAndEnable: Authentication failed. Code: %{public}d', result.result);
            const prompt = this.getUIContext().getPromptAction();
            // 401 一般是参数错误，但也可能是旧版SDK行为上的差异，这里暂且按失败处理
            prompt.showToast({ message: '验证失败，未启用生物识别', duration: 1500 });
          }
        }
      });
      userAuthInstance.start();
      hilog.debug(0xFF00, 'Settings', 'verifyBiometricAndEnable: Authentication instance started.');
    } catch (err) {
      hilog.error(0xFF00, 'Settings', '生物识别验证启动异常: %{public}s', JSON.stringify(err));
      hilog.error(0xFF00, 'Settings', '生物识别验证失败: %{public}s', String(err));
      this.biometricUnlock = false;
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '生物识别启动失败', duration: 1500 });
    }
  }

  private async handleSetPassword(): Promise<void> {
    if (this.newPassword.length < 4) {
      this.passwordError = '密码至少需要4个字符';
      return;
    }
    if (this.newPassword !== this.confirmNewPassword) {
      this.passwordError = '两次输入的密码不一致';
      return;
    }
    try {
      await this.passwordService.setPassword(this.newPassword);
      this.hasPassword = this.passwordService.hasPassword();
      this.passwordGateVersion += 1;
      hilog.debug(0xFF00, 'Settings', 'handleSetPassword: hasPassword=%{public}s, dbBackup=%{public}s, biometric=%{public}s',
        String(this.hasPassword), String(this.dbPasswordBackup), String(this.biometricUnlock));
      this.showPasswordDialog = false;
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '密码设置成功', duration: 1500 });
    } catch (e) {
      this.passwordError = '设置密码失败';
    }
  }

  private async handlePasswordConfirm(): Promise<void> {
    const hasInput = this.hasPasswordInput();
    hilog.debug(0xFF00, 'Settings', 'handlePasswordConfirm: hasInput=%{public}s, newLen=%{public}d, confirmLen=%{public}d',
      String(hasInput), this.newPassword.trim().length, this.confirmNewPassword.trim().length);
    if (!hasInput) {
      hilog.debug(0xFF00, 'Settings', 'handlePasswordConfirm(clear): before hasPassword=%{public}s, dbBackup=%{public}s, biometric=%{public}s',
        String(this.hasPassword), String(this.dbPasswordBackup), String(this.biometricUnlock));
      await this.passwordService.clearPassword();
      this.hasPassword = this.passwordService.hasPassword();
      // 清除密码后立即禁用依赖密码的选项
      this.dbPasswordBackup = false;
      this.savePref('dbPasswordBackup', false);
      this.biometricUnlock = false;
      this.savePref('biometricUnlock', false);
      this.passwordGateVersion += 1;
      hilog.debug(0xFF00, 'Settings', 'handlePasswordConfirm(clear): after hasPassword=%{public}s, dbBackup=%{public}s, biometric=%{public}s',
        String(this.hasPassword), String(this.dbPasswordBackup), String(this.biometricUnlock));
      this.showPasswordDialog = false;
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '密码已清除', duration: 1500 });
      return;
    }

    await this.handleSetPassword();
  }

  private hasPasswordInput(): boolean {
    return this.newPassword.trim().length > 0 || this.confirmNewPassword.trim().length > 0;
  }

  private async resetCopyCounts(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.authenticatorService.initialize(context);
      await this.authenticatorService.resetCopyCounts();
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '复制次数已重置', duration: 1500 });
    } catch (err) {
      hilog.error(0xFF00, 'Settings', '重置复制次数失败: %{public}s', String(err));
      try {
        this.getUIContext().getPromptAction().showToast({ message: '重置失败', duration: 1500 });
      } catch (_e) {
        // ignore
      }
    }
  }

  private async applyScreenshotPolicy(allow: boolean): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowInstance = await window.getLastWindow(context);
      hilog.info(0xFF00, 'Settings', 'applyScreenshotPolicy: allow=%{public}s, privacyMode=%{public}s', String(allow), String(!allow));
      await windowInstance.setWindowPrivacyMode(!allow);
      hilog.info(0xFF00, 'Settings', 'setWindowPrivacyMode 成功');
    } catch (err) {
      hilog.error(0xFF00, 'Settings', '设置窗口隐私模式失败: %{public}s', String(err));
    }
  }

  @Builder
  private sectionHeader(title: ResourceStr) {
    Text(title)
      .fontSize(13)
      .fontWeight(600)
      .fontColor(this.getColors().primary)
      .margin({ left: 16, top: 20, bottom: 4 })
      .width('100%')
  }

  @Builder
  private switchItem(title: ResourceStr, subtitle: ResourceStr, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontColor(this.getColors().text)
        Text(subtitle)
          .fontSize(12)
          .fontColor(this.getColors().textSecondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: 12 })

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.getColors().primary)
        .onChange((v: boolean): void => { onChange(v); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private clickItem(title: ResourceStr, value: ResourceStr, onClick: () => void) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontColor(this.getColors().text)
        Text(value)
          .fontSize(12)
          .fontColor(this.getColors().textSecondary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.baseline_chevron_right_24'))
        .width(20).height(20)
        .fillColor(this.getColors().textSecondary)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => { onClick(); })
  }

  @Builder
  private switchItemWithEnabled(title: ResourceStr, subtitle: ResourceStr, isOn: boolean, onChange: (v: boolean) => void, enabled: boolean) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontColor(enabled ? this.getColors().text : this.getColors().textSecondary)
        Text(subtitle)
          .fontSize(12)
          .fontColor(this.getColors().textSecondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: 12 })

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.getColors().primary)
        .enabled(enabled)
        .onChange((v: boolean): void => {
          hilog.debug(0xFF00, 'Settings', 'switchItemWithEnabled: enabled=%{public}s, value=%{public}s',
            String(enabled), String(v));
          if (!enabled) {
            return;
          }
          onChange(v);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .opacity(enabled ? 1.0 : 0.4)
    .enabled(enabled)
  }

  @Builder
  private clickItemWithEnabled(title: ResourceStr, value: ResourceStr, onClick: () => void, enabled: boolean) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontColor(enabled ? this.getColors().text : this.getColors().textSecondary)
        Text(value)
          .fontSize(12)
          .fontColor(this.getColors().textSecondary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.baseline_chevron_right_24'))
        .width(20).height(20)
        .fillColor(this.getColors().textSecondary)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .opacity(enabled ? 1.0 : 0.4)
    .onClick((): void => { if (enabled) { onClick(); } })
  }

  @Builder
  private buildListPicker(title: ResourceStr, items: ResourceStr[], selectedIndex: number,
    onSelect: (index: number) => void, onCancel: () => void) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick((): void => { onCancel(); })

      Column({ space: 0 }) {
        Text(title)
          .fontSize(18)
          .fontWeight(700)
          .fontColor(this.getColors().text)
          .margin({ top: 16, bottom: 12 })

        List() {
          ForEach(items, (item: ResourceStr, index: number) => {
            ListItem() {
              Row() {
                Text(item)
                  .fontSize(16)
                  .fontColor(index === selectedIndex ? this.getColors().primary : this.getColors().text)
                  .fontWeight(index === selectedIndex ? FontWeight.Bold : FontWeight.Normal)
                  .flexGrow(1)
                if (index === selectedIndex) {
                  Image($r('app.media.baseline_done_24'))
                    .width(20).height(20)
                    .fillColor(this.getColors().primary)
                }
              }
              .width('100%')
              .height(48)
              .padding({ left: 20, right: 20 })
              .onClick((): void => { onSelect(index); })
            }
          }, (_item: ResourceStr, index: number): string => `picker_${index}`)
        }
        .width('100%')

        Button('取消')
          .width('90%')
          .height(44)
          .backgroundColor(this.getColors().surface)
          .fontColor(this.getColors().text)
          .borderRadius(22)
          .margin({ top: 8, bottom: 16 })
          .onClick((): void => { onCancel(); })
      }
      .width('85%')
      .backgroundColor(this.getColors().background)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('transparent')
  }
}
