// Index.ets

import { AuthenticatorService } from '../core/service/impl/AuthenticatorService';
import { Authenticator } from '../core/entity/Authenticator';
import { Category } from '../core/entity/Category';
import { AuthenticatorItem } from '../components/AuthenticatorItem';
import { AuthenticatorType } from '../core/AuthenticatorType';
import { HashAlgorithm } from '../core/generator/HashAlgorithm';
import { AddMenuSheet } from './index/components/AddMenuSheet';
import { EditAuthenticatorSheet } from './index/components/EditAuthenticatorSheet';
import { ImportPasswordDialog } from './index/components/ImportPasswordDialog';
import { PinUnlockSheet } from './index/components/PinUnlockSheet';
import { EmptyState } from './index/components/EmptyState';
import { TopBar } from './index/components/TopBar';
import { BottomBar } from './index/components/BottomBar';
import { QrScannerOverlay } from './index/components/QrScannerOverlay';
import { EditDetails } from './index/components/EditDetails';
import { InputOTPKey } from './index/components/InputOTPKey';
import { ChangeIconSheet } from './index/components/ChangeIconSheet';
import { CategorySheet } from './index/components/CategorySheet';
import { QrCodeSheet } from './index/components/QrCodeSheet';
import { MainMenu } from '../components/MainMenu';
import { SortMenu } from '../components/SortMenu';
import { EditMenu } from '../components/EditMenu';
import { BackupMenu } from '../components/BackupMenu';
import { BackupService } from '../core/service/impl/BackupService';
import { CategoryService } from '../core/service/impl/CategoryService';
import { IconPackService } from '../core/service/impl/IconPackService';
import { CategoryManager } from '../components/CategoryManager';
import { SortFilterManager } from '../components/SortFilterManager';
import { ThemeManager, ThemeMode, ThemeColors } from '../core/util/ThemeManager';
import { IconResolver } from '../core/util/IconResolver';
import { CommonConstants } from '../constants/CommonConstants';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { UriBytesReader } from '../core/util/UriBytesReader';
import { PasswordService } from '../core/service/impl/PasswordService';
import { PasswordSetupDialog } from './index/components/PasswordSetupDialog';
import { window } from '@kit.ArkUI';
import preferences from '@ohos.data.preferences';
import { userAuth } from '@kit.UserAuthenticationKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { CustomIconService } from '../core/service/impl/CustomIconService';
import { UriParser } from '../core/UriParser';
import { util } from '@kit.ArkTS';

const UNCATEGORIZED_CATEGORY_ID: string = '__uncategorized__';
const PENDING_OTP_URI_KEY: string = 'pendingOtpUri';

/**
 * 主页面
 */
@Entry
@Component
struct Index {
  private authenticatorService: AuthenticatorService = AuthenticatorService.getInstance();
  private backupService: BackupService = new BackupService();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private categoryManager: CategoryManager = new CategoryManager();
  private sortFilterManager: SortFilterManager = new SortFilterManager();
  private passwordService: PasswordService = PasswordService.getInstance();
  private iconPackService: IconPackService = IconPackService.getInstance();
  private customIconService: CustomIconService = CustomIconService.getInstance();

  @State authenticators: Array<Authenticator> = [];
  @State filteredAuthenticators: Array<Authenticator> = [];
  @State categories: Array<Category> = [];
  @State isLoading: boolean = false;
  @State showEditMenu: boolean = false;
  @State selectedAuthenticator: Authenticator | null = null;
  @State showEditSheet: boolean = false;
  @State showEditDetails: boolean = false;
  @State showInputKey: boolean = false;
  @State progress: number = 100;
  @State isDarkMode: boolean = false;
  @State showAddMenu: boolean = false;
  @State showImportPasswordDialog: boolean = false;
  @State importPassword: string = '';
  @State showExportPasswordDialog: boolean = false;
  @State exportPassword: string = '';
  @State showPinSheet: boolean = false;
  @State showMainMenu: boolean = false;
  @State showSortMenu: boolean = false;
  @State showBackupMenu: boolean = false;
  @State showQrScanner: boolean = false;
  @State showChangeIconSheet: boolean = false;
  @State showCategorySheet: boolean = false;
  @State showQrCodeSheet: boolean = false;
  @State showSearchBar: boolean = false;
  @State searchText: string = '';
  @State currentSortOption: string = 'alphabetical_asc';
  @State lockOrdering: boolean = false;
  @State selectedCategoryId: string | null = null;
  @State currentCategoryName: string = '全部';
  private pendingEncryptedData: Uint8Array | null = null;
  private pendingEncryptedType: string | null = null;
  @State isFirstLaunch: boolean = false;
  @State showPasswordSetup: boolean = false;
  @State showUnlockDialog: boolean = false;
  @State isLocked: boolean = true;
  @State allowBiometricUnlock: boolean = false;
  @State biometricSupported: boolean = false;
  @State unlockError: string = '';
  @State isUnlocking: boolean = false;
  @State editingOriginalId: string | null = null;
  @State tapToCopy: boolean = true;
  @State tapToReveal: boolean = false;
  @State tapToRevealDuration: number = 10;
  @State skipToNext: boolean = false;
  @State codeGroupSize: number = 3;
  @State showUsernames: boolean = true;
  @State backupReminder: boolean = true;
  @State autoBackupEnabled: boolean = false;
  @State autoBackupPath: string = '';
  @State autoBackupPassword: string = '';
  @State showUncategorized: boolean = true;
  @State viewMode: string = 'default';
  @State timeoutSeconds: number = 0;
  @State themeColors: ThemeColors = ThemeManager.getInstance().getColors();
  private progressTimerId: number | null = null;
  private lastInactiveAt: number = 0;
  private themeListener: () => void = (): void => {
    this.isDarkMode = this.themeManager.isDarkLike();
    this.themeColors = this.themeManager.getColors();
    this.syncSystemBars();
  }

  private syncSystemBars(): void {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      window.getLastWindow(ctx).then((win: window.Window) => {
        const surface = this.themeColors.surface;
        const onBg = this.themeColors.onBackground;
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: surface,
          statusBarContentColor: onBg,
          navigationBarContentColor: onBg
        });
      }).catch((_e: Error) => {});
    } catch (_e) {
      // ignore
    }
  }

  /**
   * 页面每次显示时执行（包括从设置页返回）
   */
  onPageShow(): void {
    this.refreshPageSettings();
    this.isDarkMode = this.themeManager.isDarkLike();
    this.themeColors = this.themeManager.getColors();
    this.syncSystemBars();
  }

  private async refreshPageSettings(): Promise<void> {
    await this.loadUserPreferences();
    await this.applyTimeoutLockPolicy();
    await this.applyScreenshotPolicy();
    if (!this.showUncategorized && this.selectedCategoryId === UNCATEGORIZED_CATEGORY_ID) {
      this.selectedCategoryId = null;
      this.currentCategoryName = '全部';
    }
    this.applyFilters();
  }

  /**
   * 页面出现时执行
   */
  async aboutToAppear(): Promise<void> {
    this.themeManager.addListener(this.themeListener);
    this.isDarkMode = this.themeManager.isDarkLike();
    this.themeColors = this.themeManager.getColors();
    this.syncSystemBars();
    // 初始化持久化存储
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.authenticatorService.initialize(context);
      await CategoryService.getInstance().initialize(context);
      await this.passwordService.initialize(context);
      await this.iconPackService.initialize(context);
      await this.customIconService.initialize(context);

      // 读取解锁相关设置
      try {
        const settingsStore = await preferences.getPreferences(context, 'settings_prefs');
        this.allowBiometricUnlock = (await settingsStore.get('biometricUnlock', false)) as boolean;
        this.tapToCopy = (await settingsStore.get('tapToCopy', true)) as boolean;
        this.tapToReveal = (await settingsStore.get('tapToReveal', false)) as boolean;
        this.tapToRevealDuration = (await settingsStore.get('tapToRevealDuration', 10)) as number;
        this.skipToNext = (await settingsStore.get('skipToNext', false)) as boolean;
        this.codeGroupSize = (await settingsStore.get('codeGroupSize', 3)) as number;
        this.showUsernames = (await settingsStore.get('showUsernames', true)) as boolean;
        this.backupReminder = (await settingsStore.get('backupReminder', true)) as boolean;
        this.autoBackupEnabled = (await settingsStore.get('autoBackup', false)) as boolean;
        this.autoBackupPath = (await settingsStore.get('autoBackupPath', '')) as string;
        this.autoBackupPassword = (await settingsStore.get('autoBackupPassword', '')) as string;
        this.showUncategorized = (await settingsStore.get('showUncategorized', true)) as boolean;
        this.viewMode = (await settingsStore.get('viewMode', 'default')) as string;
        this.timeoutSeconds = (await settingsStore.get('timeoutSeconds', 0)) as number;
        this.lockOrdering = (await settingsStore.get('lockOrdering', false)) as boolean;
        this.currentSortOption = (await settingsStore.get('sortOption', 'alphabetical_asc')) as string;
        
        // 恢复主题设置
        const savedTheme = (await settingsStore.get('themeMode', 'system')) as string;
        if (savedTheme === 'dark') {
          this.themeManager.setTheme(ThemeMode.DARK);
        } else if (savedTheme === 'black') {
          this.themeManager.setTheme(ThemeMode.BLACK);
        } else if (savedTheme === 'light') {
          this.themeManager.setTheme(ThemeMode.LIGHT);
        } else {
          try {
            const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
            const isDark = ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
            this.themeManager.setTheme(isDark ? ThemeMode.DARK : ThemeMode.LIGHT);
          } catch (_themeErr) {
            this.themeManager.setTheme(ThemeMode.LIGHT);
          }
        }
        const savedAccent = (await settingsStore.get('accentColor', 'default')) as string;
        this.themeManager.setAccentId(savedAccent);
        this.isDarkMode = this.themeManager.isDarkLike();
        this.themeColors = this.themeManager.getColors();

      } catch (_e) {
        this.allowBiometricUnlock = false;
      }

      // 检测生物识别可用性
      this.biometricSupported = this.checkBiometricAvailability();

      // 检查是否首次启动 → 跳转引导页
      if (this.passwordService.isFirstLaunch()) {
        await this.passwordService.setFirstLaunchComplete();
        try {
          await this.getUIContext().getRouter().replaceUrl({ url: 'pages/Intro' });
        } catch (navErr) {
          console.error('导航到引导页失败:', navErr);
        }
        return;
      } else if (this.passwordService.hasPassword()) {
        // 已设置密码，需要解锁
        this.isLocked = true;
        this.showPinSheet = true;
        this.unlockError = '';
        this.authenticators = [];
        this.filteredAuthenticators = [];
        if (this.progressTimerId !== null) {
          clearInterval(this.progressTimerId);
          this.progressTimerId = null;
        }
        // 应用截图策略
        this.applyScreenshotPolicy();

        if (this.allowBiometricUnlock && this.biometricSupported) {
          this.tryBiometricUnlock();
        }
        return;
      } else {
        this.isLocked = false;
      }
    } catch (err) {
      console.error('初始化存储失败:', err);
    }
    await this.loadAuthenticators();
    this.loadCategories();
    this.startProgressTimer();
    await this.consumePendingOtpUri();

    // 应用截图策略
    this.applyScreenshotPolicy();
  }

  private async loadUserPreferences(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const settingsStore = await preferences.getPreferences(context, 'settings_prefs');
      this.tapToCopy = (await settingsStore.get('tapToCopy', true)) as boolean;
      this.tapToReveal = (await settingsStore.get('tapToReveal', false)) as boolean;
      this.tapToRevealDuration = (await settingsStore.get('tapToRevealDuration', 10)) as number;
      this.skipToNext = (await settingsStore.get('skipToNext', false)) as boolean;
      this.codeGroupSize = (await settingsStore.get('codeGroupSize', 3)) as number;
      this.showUsernames = (await settingsStore.get('showUsernames', true)) as boolean;
      this.allowBiometricUnlock = (await settingsStore.get('biometricUnlock', false)) as boolean;
      this.backupReminder = (await settingsStore.get('backupReminder', true)) as boolean;
      this.autoBackupEnabled = (await settingsStore.get('autoBackup', false)) as boolean;
      this.autoBackupPath = (await settingsStore.get('autoBackupPath', '')) as string;
      this.autoBackupPassword = (await settingsStore.get('autoBackupPassword', '')) as string;
      this.showUncategorized = (await settingsStore.get('showUncategorized', true)) as boolean;
      this.viewMode = (await settingsStore.get('viewMode', 'default')) as string;
      this.timeoutSeconds = (await settingsStore.get('timeoutSeconds', 0)) as number;
      this.lockOrdering = (await settingsStore.get('lockOrdering', false)) as boolean;
      this.currentSortOption = (await settingsStore.get('sortOption', this.currentSortOption)) as string;
    } catch (err) {
      console.error('读取用户偏好失败:', err);
    }
  }

  private async applyTimeoutLockPolicy(): Promise<void> {
    if (this.timeoutSeconds <= 0 || this.isLocked || !this.passwordService.hasPassword() || this.lastInactiveAt <= 0) {
      return;
    }

    const elapsedSeconds = Math.floor((Date.now() - this.lastInactiveAt) / 1000);
    if (elapsedSeconds < this.timeoutSeconds) {
      return;
    }

    this.isLocked = true;
    this.showPinSheet = true;
    this.unlockError = '';
    this.authenticators = [];
    this.filteredAuthenticators = [];
    if (this.progressTimerId !== null) {
      clearInterval(this.progressTimerId);
      this.progressTimerId = null;
    }
  }

  /**
   * 读取设置并应用截图隐私策略
   */
  private async applyScreenshotPolicy(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const store = await preferences.getPreferences(context, 'settings_prefs');
      const allowScreenshots = (await store.get('allowScreenshots', false)) as boolean;
      const windowInstance = await window.getLastWindow(context);
      console.info(`[Index] applyScreenshotPolicy: allow=${allowScreenshots}, privacyMode=${!allowScreenshots}`);
      await windowInstance.setWindowPrivacyMode(!allowScreenshots);
    } catch (err) {
      console.error('应用截图策略失败:', err);
    }
  }

  /**
   * 页面消失时执行
   */
  aboutToDisappear() {
    this.lastInactiveAt = Date.now();
    this.themeManager.removeListener(this.themeListener);
    if (this.progressTimerId !== null) {
      clearInterval(this.progressTimerId);
      this.progressTimerId = null;
    }
  }

  /**
   * 加载认证器列表
   */
  async loadAuthenticators() {
    this.isLoading = true;
    try {
      this.authenticators = await this.authenticatorService.getAll();
      this.applyFilters();
    } catch (error) {
      console.error('Failed to load authenticators:', error);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '加载认证器失败', duration: 1500 });
      } catch (toastError) {
        // ignore
      }
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 获取当前主题色
   */
  getColors(): ThemeColors {
    return this.themeColors;
  }

  /**
   * 加载分类列表
   */
  async loadCategories() {
    this.categories = await this.categoryManager.loadCategories();
  }

  /**
   * 应用排序和搜索过滤
   */
  applyFilters() {
    let filtered = this.authenticators;

    // Filter by Category
    if (this.selectedCategoryId === UNCATEGORIZED_CATEGORY_ID) {
      filtered = filtered.filter(auth => !auth.categoryId);
    } else if (this.selectedCategoryId) {
      filtered = filtered.filter(auth => auth.categoryId === this.selectedCategoryId);
    }

    // Filter by Search
    filtered = this.sortFilterManager.applySearchFilter(filtered, this.searchText);

    // Sort
    filtered = this.sortFilterManager.sortAuthenticators(filtered, this.currentSortOption);

    this.filteredAuthenticators = filtered;
  }

  /**
   * 搜索文本变化
   */
  onSearchChange(value: string) {
    this.searchText = value;
    this.applyFilters();
  }

  /**
   * 排序选项变化
   */
  onSortChange(option: string) {
    this.currentSortOption = option;
    this.showSortMenu = false;
    this.persistSortPrefs();
    this.applyFilters();
  }

  private async onToggleLockOrdering(): Promise<void> {
    this.lockOrdering = !this.lockOrdering;
    await this.persistSortPrefs();
  }

  private async persistSortPrefs(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const store = await preferences.getPreferences(context, 'settings_prefs');
      await store.put('sortOption', this.currentSortOption);
      await store.put('lockOrdering', this.lockOrdering);
      await store.flush();
    } catch (err) {
      console.error('保存排序偏好失败:', err);
    }
  }

  private async onListReorder(from: number, to: number): Promise<void> {
    if (this.currentSortOption !== 'custom' || this.lockOrdering) {
      return;
    }
    if (from === to || from < 0 || to < 0) {
      return;
    }
    const moved = this.filteredAuthenticators.splice(from, 1);
    if (moved.length === 0) {
      return;
    }
    this.filteredAuthenticators.splice(to, 0, moved[0]);
    // Trigger UI refresh
    this.filteredAuthenticators = [...this.filteredAuthenticators];

    const ids: string[] = this.filteredAuthenticators.map((auth: Authenticator): string =>
      this.authenticatorService.generateId(auth));
    try {
      await this.authenticatorService.reorder(ids);
      this.authenticators = await this.authenticatorService.getAll();
      await this.runAutoBackupIfEnabled();
    } catch (err) {
      console.error('重排序失败:', err);
    }
  }

  private async consumePendingOtpUri(): Promise<void> {
    let pending = '';
    try {
      pending = AppStorage.get(PENDING_OTP_URI_KEY) as string || '';
    } catch (_e) {
      pending = '';
    }
    if (!pending) {
      return;
    }
    try {
      AppStorage.setOrCreate(PENDING_OTP_URI_KEY, '');
    } catch (_e) {
      // ignore
    }
    await this.addAuthenticatorFromUri(pending);
  }

  private async addAuthenticatorFromUri(uri: string): Promise<void> {
    const value = uri.trim();
    if (!value) {
      return;
    }
    try {
      const iconResolver = new IconResolver();
      if (value.startsWith('otpauth-migration://')) {
        const list = UriParser.parseOtpAuthMigrationUri(value, iconResolver);
        for (const auth of list) {
          await this.authenticatorService.create(auth);
        }
        await this.loadAuthenticators();
        await this.runAutoBackupIfEnabled();
        this.showToast(`已从链接导入 ${list.length} 个认证器`);
        return;
      }
      if (value.startsWith('otpauth://') || value.startsWith('motp://')) {
        const parsed = UriParser.parseStandardUri(value, iconResolver);
        await this.authenticatorService.create(parsed.authenticator);
        await this.loadAuthenticators();
        await this.runAutoBackupIfEnabled();
        this.showToast(`已添加: ${parsed.authenticator.issuer || '认证器'}`);
      }
    } catch (err) {
      console.error('处理 Deep Link 失败:', err);
      this.showToast('无法从链接添加认证器');
    }
  }

  /**
   * 选择分类
   */
  async onSelectCategory(id: string | null) {
    this.selectedCategoryId = id;
    this.currentCategoryName = id === UNCATEGORIZED_CATEGORY_ID
      ? '未分类'
      : this.categoryManager.getCurrentCategoryName(id, this.categories);
    this.showMainMenu = false;
    this.applyFilters();
  }

  /**
   * 启动进度计时器
   */
  startProgressTimer() {
    if (this.progressTimerId !== null) {
      clearInterval(this.progressTimerId);
    }

    // 每100毫秒更新一次进度
    this.progressTimerId = setInterval(() => {
      const now = Date.now() / 1000;
      const period = 30;
      const remaining = period - (now % period);
      const progress = (remaining / period) * 100;
      this.progress = progress;
    }, 100);
  }

  /**
   * 显示编辑选项
   * @param auth 认证器
   */
  showEditOptions(auth: Authenticator) {
    this.selectedAuthenticator = auth;
    this.showEditMenu = true;
  }

  /**
   * 隐藏编辑选项
   */
  hideEditOptions() {
    this.showEditMenu = false;
    this.selectedAuthenticator = null;
  }

  // Edit sheet handlers
  closeEditSheet() {
    this.showEditSheet = false;
    // keep selectedAuthenticator until sheet is closed
  }

  async handleSaveEdited(updated: Authenticator) {
    try {
      await this.authenticatorService.update(updated);
      await this.loadAuthenticators();
      await this.runAutoBackupIfEnabled();
      this.closeEditSheet();
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '保存成功', duration: 1500 });
      } catch (toastError) {
        console.error('Failed to show toast:', toastError);
      }
    } catch (error) {
      console.error('保存认证器失败:', error);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '保存失败', duration: 1500 });
      } catch (toastError) {
        console.error('Failed to show toast:', toastError);
      }
    }
  }

  async handleDeleteFromSheet(target: Authenticator) {
    try {
      const id = `${target.issuer}:${target.username}:${target.secret}`;
      await this.authenticatorService.delete(id);
      await this.loadAuthenticators();
      await this.runAutoBackupIfEnabled();
      this.closeEditSheet();
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '删除成功', duration: 1500 });
      } catch (toastError) {
        console.error('Failed to show toast:', toastError);
      }
    } catch (error) {
      console.error('删除失败:', error);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '删除失败', duration: 1500 });
      } catch (toastError) {
        console.error('Failed to show toast:', toastError);
      }
    }
  }

  /**
   * 添加认证器
   */
  async addAuthenticator() {
    // 这里保留原始快速添加用于调试/测试
    const authenticator = new Authenticator();
    authenticator.issuer = 'Test';
    authenticator.username = 'test@example.com';
    authenticator.secret = 'JBSWY3DPEHPK3PXP';
    authenticator.type = AuthenticatorType.Totp;
    authenticator.algorithm = HashAlgorithm.Sha1;
    authenticator.digits = 6;
    authenticator.period = 30;

    try {
      await this.authenticatorService.create(authenticator);
      await this.loadAuthenticators();
      await this.runAutoBackupIfEnabled();
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '添加成功', duration: 1500 });
      } catch (toastError) {
        console.error('Failed to show toast:', toastError);
      }
    } catch (error) {
      console.error('添加认证器失败:', error);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '添加失败', duration: 1500 });
      } catch (toastError) {
        console.error('Failed to show toast:', toastError);
      }
    }
  }

  // 打开/关闭添加菜单
  closeAddMenu() {
    this.showAddMenu = false;
  }

  handleScan() {
    this.closeAddMenu();
    this.showQrScanner = true;
  }

  handleEnterKey() {
    this.closeAddMenu();
    this.editingOriginalId = null;
    // 打开手动输入密钥面板
    this.showInputKey = true;
  }

  handleRestore() {
    this.closeAddMenu();
    this.importFromFile();
  }

  handleImport() {
    this.closeAddMenu();
    // 导航到从其他应用导入页面
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ImportSource' });
    } catch (e) {
      console.error('导航到导入页失败:', e);
    }
  }

  // Pin sheet handlers
  openPinSheet() {
    this.showPinSheet = true;
  }

  closePinSheet() {
    this.showPinSheet = false;
  }

  onPinConfirm(pin: string) {
    this.unlockWithPassword(pin);
  }

  private async unlockWithPassword(pin: string): Promise<void> {
    this.isUnlocking = true;
    this.unlockError = '';
    try {
      if (await this.passwordService.verifyPassword(pin)) {
        this.isLocked = false;
        this.showPinSheet = false;
        await this.loadAuthenticators();
        this.loadCategories();
        this.startProgressTimer();
        await this.consumePendingOtpUri();
      } else {
        this.unlockError = '密码错误';
        this.showPinSheet = true;
      }
    } finally {
      this.isUnlocking = false;
    }
  }

  private checkBiometricAvailability(): boolean {
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL3);
      return true;
    } catch (_e) {
      try {
        userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL3);
        return true;
      } catch (_e2) {
        return false;
      }
    }
  }

  private tryBiometricUnlock(): void {
    const authTypes: userAuth.UserAuthType[] = [];
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL3);
      authTypes.push(userAuth.UserAuthType.FINGERPRINT);
    } catch (_e) {}
    
    // 如果指纹不可用，则尝试面部识别
    if (authTypes.length === 0) {
      try {
        userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL3);
        authTypes.push(userAuth.UserAuthType.FACE);
      } catch (_e) {}
    }

    if (authTypes.length === 0) {
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '未检测到可用的生物识别方式', duration: 1500 });
      } catch (e) {
        console.error('Show toast failed:', e);
      }
      return;
    }

    try {
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
        title: '解锁',
        uiContext: context
      };
      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      userAuthInstance.on('result', {
        onResult: async (result: userAuth.UserAuthResult): Promise<void> => {
          console.info('Biometric unlock result:', result.result);
          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            this.isLocked = false;
            this.showPinSheet = false;
            await this.loadAuthenticators();
            this.loadCategories();
            this.startProgressTimer();
            await this.consumePendingOtpUri();
          } else {
             // 12500003 是用户取消，不需要提示
             if (result.result !== 12500003) {
                try {
                  const prompt = this.getUIContext().getPromptAction();
                  prompt.showToast({ message: '验证失败: ' + result.result, duration: 1500 });
                } catch (e) {}
             }
          }
        }
      });
      userAuthInstance.start();
    } catch (err) {
      console.error('生物识别解锁启动失败:', err);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '启动生物识别失败', duration: 1500 });
      } catch (e) {}
    }
  }

  /**
   * 首次设置密码回调
   */
  async onPasswordSetup(password: string): Promise<void> {
    try {
      await this.passwordService.setPassword(password);
      await this.passwordService.setFirstLaunchComplete();
      this.showPasswordSetup = false;
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '密码设置成功', duration: 1500 });
    } catch (e) {
      console.error('设置密码失败:', e);
    }
  }

  /**
   * 跳过密码设置
   */
  async onSkipPasswordSetup(): Promise<void> {
    try {
      await this.passwordService.setFirstLaunchComplete();
      this.showPasswordSetup = false;
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '你可以稍后在设置中配置密码', duration: 2000 });
    } catch (e) {
      console.error('跳过密码设置失败:', e);
    }
  }

  closeImportPasswordDialog() {
    this.showImportPasswordDialog = false;
    this.importPassword = '';
    this.pendingEncryptedData = null;
    this.pendingEncryptedType = null;
  }

  closeExportPasswordDialog() {
    this.showExportPasswordDialog = false;
    this.exportPassword = '';
  }

  // ===== 文件导入相关方法 =====

  private async readFileBytesFromUri(uri: string): Promise<Uint8Array> {
    return UriBytesReader.read(uri);
  }

  private bytesToString(data: Uint8Array): string {
    let result = '';
    let i = 0;
    while (i < data.length) {
      const byte1 = data[i];
      if (byte1 < 0x80) {
        result += String.fromCharCode(byte1);
        i++;
      } else if ((byte1 & 0xE0) === 0xC0 && i + 1 < data.length) {
        const byte2 = data[i + 1];
        result += String.fromCharCode(((byte1 & 0x1F) << 6) | (byte2 & 0x3F));
        i += 2;
      } else if ((byte1 & 0xF0) === 0xE0 && i + 2 < data.length) {
        const byte2 = data[i + 1];
        const byte3 = data[i + 2];
        result += String.fromCharCode(((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F));
        i += 3;
      } else if ((byte1 & 0xF8) === 0xF0 && i + 3 < data.length) {
        const byte2 = data[i + 1];
        const byte3 = data[i + 2];
        const byte4 = data[i + 3];
        const codePoint = ((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F);
        result += String.fromCharCode(0xD800 + ((codePoint - 0x10000) >> 10));
        result += String.fromCharCode(0xDC00 + ((codePoint - 0x10000) & 0x3FF));
        i += 4;
      } else {
        result += String.fromCharCode(byte1);
        i++;
      }
    }
    return result;
  }

  private async saveFile(content: string | Uint8Array, fileName: string): Promise<boolean> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.newFileNames = [fileName];
    const documentViewPicker = new picker.DocumentViewPicker(context);
    const uris = await documentViewPicker.save(documentSaveOptions);
    if (!uris || uris.length === 0) {
      return false;
    }

    const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE);
    try {
      fs.writeSync(file.fd, content);
      return true;
    } finally {
      fs.closeSync(file);
    }
  }

  private async writeFile(content: string | Uint8Array, filePath: string): Promise<void> {
    const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    try {
      fs.writeSync(file.fd, content);
    } finally {
      fs.closeSync(file);
    }
  }

  private generateBackupFileName(extension: string): string {
    const now = new Date();
    const pad = (value: number): string => value.toString().padStart(2, '0');
    const stamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
    return `backup-${stamp}.${extension}`;
  }

  private showToast(message: string, duration: number = 1500): void {
    try {
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: message, duration: duration });
    } catch (error) {
      console.error('显示提示失败:', error);
    }
  }

  private async exportBackupContent(content: string | Uint8Array, extension: string, successMessage: string): Promise<void> {
    try {
      const success = await this.saveFile(content, this.generateBackupFileName(extension));
      this.showToast(success ? successMessage : '已取消保存');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('备份保存失败:', error);
      this.showToast(`备份失败: ${message}`, 2000);
    }
  }

  private async runAutoBackupIfEnabled(): Promise<void> {
    await this.loadUserPreferences();
    if (!this.autoBackupEnabled) {
      if (this.backupReminder) {
        this.showToast('认证器已更改，请考虑创建备份', 1500);
      }
      return;
    }

    if (!this.autoBackupPath) {
      this.showToast('自动备份未选择保存位置', 1800);
      return;
    }

    try {
      const hasPassword = this.autoBackupPassword.trim().length > 0;
      const content = hasPassword
        ? await this.backupService.createEncryptedBackupAsync(this.autoBackupPassword)
        : await this.backupService.createBackupAsync();
      const extension = hasPassword ? 'stratum' : 'json';
      const separator = this.autoBackupPath.endsWith('/') ? '' : '/';
      const targetPath = `${this.autoBackupPath}${separator}${this.generateBackupFileName(extension)}`;
      await this.writeFile(content, targetPath);
      this.showToast('自动备份已保存', 1500);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('自动备份失败:', error);
      this.showToast(`自动备份失败: ${message}`, 2200);
    }
  }

  private headerMatches(data: Uint8Array, header: string): boolean {
    if (data.length < header.length) {
      return false;
    }
    for (let i = 0; i < header.length; i++) {
      if (data[i] !== header.charCodeAt(i)) {
        return false;
      }
    }
    return true;
  }

  private isStrongEncrypted(data: Uint8Array): boolean {
    return this.headerMatches(data, 'AUTHENTICATORPRO');
  }

  private isLegacyEncrypted(data: Uint8Array): boolean {
    return this.headerMatches(data, 'AuthenticatorPro');
  }

  private getBackupField(item: Record<string, Object>, ...keys: string[]): Object | undefined {
    for (const key of keys) {
      const value = item[key];
      if (value !== undefined && value !== null) {
        return value;
      }
    }
    return undefined;
  }

  private fieldToString(value: Object | undefined, fallback: string = ''): string {
    if (value === undefined || value === null) {
      return fallback;
    }
    return String(value);
  }

  private fieldToNumber(value: Object | undefined, fallback: number): number {
    if (value === undefined || value === null) {
      return fallback;
    }
    const parsed = Number(value);
    return isNaN(parsed) ? fallback : parsed;
  }

  private parseBackupAuthenticatorType(value: Object | undefined): AuthenticatorType {
    const text = this.fieldToString(value, '').toLowerCase();
    if (text === 'hotp') {
      return AuthenticatorType.Hotp;
    }
    if (text === 'totp') {
      return AuthenticatorType.Totp;
    }
    if (text === 'mobileotp' || text === 'motp') {
      return AuthenticatorType.MobileOtp;
    }
    if (text === 'steamotp' || text === 'steam') {
      return AuthenticatorType.SteamOtp;
    }
    if (text === 'yandexotp' || text === 'yaotp') {
      return AuthenticatorType.YandexOtp;
    }

    switch (this.fieldToNumber(value, 2)) {
      case 1:
        return AuthenticatorType.Hotp;
      case 2:
        return AuthenticatorType.Totp;
      case 3:
        return AuthenticatorType.MobileOtp;
      case 4:
        return AuthenticatorType.SteamOtp;
      case 5:
        return AuthenticatorType.YandexOtp;
      case 0:
        return AuthenticatorType.Totp;
      default:
        return AuthenticatorType.Totp;
    }
  }

  private parseBackupHashAlgorithm(value: Object | undefined): HashAlgorithm {
    const text = this.fieldToString(value, '').toLowerCase();
    if (text === 'sha256') {
      return HashAlgorithm.Sha256;
    }
    if (text === 'sha512') {
      return HashAlgorithm.Sha512;
    }
    return this.fieldToNumber(value, HashAlgorithm.Sha1) as HashAlgorithm;
  }

  /**
   * 从文件导入（先选择文件，再检测加密类型）
   */
  async importFromFile(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = [
        'JSON|.json',
        'Text|.txt',
        'HTML|.html,.htm',
        'Backup|.stratum'
      ];

      const uris = await documentViewPicker.select(documentSelectOptions);
      if (!uris || uris.length === 0) {
        return;
      }

      const uri = uris[0];
      const data = await this.readFileBytesFromUri(uri);

      // 检测加密类型
      if (this.isStrongEncrypted(data)) {
        this.pendingEncryptedData = data;
        this.pendingEncryptedType = 'strong';
        this.showImportPasswordDialog = true;
        return;
      }

      if (this.isLegacyEncrypted(data)) {
        this.pendingEncryptedData = data;
        this.pendingEncryptedType = 'legacy';
        this.showImportPasswordDialog = true;
        return;
      }

      // 明文文件，直接导入
      const content = this.bytesToString(data);
      await this.importFromContent(content);
    } catch (error) {
      console.error('文件导入失败:', error);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({
          message: '导入失败: ' + (error instanceof Error ? error.message : String(error)),
          duration: 2000
        });
      } catch (e) {
        console.error('Failed:', e);
      }
    }
  }

  /**
   * 从文本内容导入认证器
   */
  async importFromContent(content: string): Promise<void> {
    try {
      const parsed = JSON.parse(content) as Record<string, Object>;

      const categoryService = CategoryService.getInstance();
      const secretCategoryMap: Map<string, string> = new Map();

      const categoriesValue = parsed['Categories'] || parsed['categories'];
      if (Array.isArray(categoriesValue)) {
        for (const categoryItem of categoriesValue as Array<Record<string, Object>>) {
          const name = this.fieldToString(this.getBackupField(categoryItem, 'Name', 'name'), '').trim();
          if (!name) {
            continue;
          }
          const id = this.fieldToString(this.getBackupField(categoryItem, 'Id', 'id'), `${name}_${Date.now()}`);
          const ranking = this.fieldToNumber(this.getBackupField(categoryItem, 'Ranking', 'ranking'), 0);
          const category = new Category(name, id, ranking);
          try {
            await categoryService.create(category);
          } catch (err) {
            console.error('导入分类失败:', err);
          }
        }
      }

      const bindingsValue = parsed['AuthenticatorCategories'] || parsed['authenticatorCategories'];
      if (Array.isArray(bindingsValue)) {
        for (const bindingItem of bindingsValue as Array<Record<string, Object>>) {
          const secret = this.fieldToString(this.getBackupField(bindingItem, 'AuthenticatorSecret', 'authenticatorSecret'), '');
          const categoryId = this.fieldToString(this.getBackupField(bindingItem, 'CategoryId', 'categoryId'), '');
          if (secret && categoryId) {
            secretCategoryMap.set(secret, categoryId);
          }
        }
      }

      // inkchills/Stratum 格式: { Authenticators: [...] }
      const authsValue = parsed['Authenticators'] || parsed['authenticators'];
      const auths = Array.isArray(authsValue) ? authsValue as Array<Record<string, Object>> : undefined;
      if (Array.isArray(auths)) {
        let addedCount = 0;
        let hasCustomRanking = false;
        for (const item of auths) {
          try {
            const auth = new Authenticator();
            auth.issuer = this.fieldToString(this.getBackupField(item, 'Issuer', 'issuer'), '');
            auth.username = this.fieldToString(this.getBackupField(item, 'Username', 'username'), '');
            auth.secret = this.fieldToString(this.getBackupField(item, 'Secret', 'secret'), '');
            auth.type = this.parseBackupAuthenticatorType(this.getBackupField(item, 'Type', 'type'));
            auth.icon = this.fieldToString(this.getBackupField(item, 'Icon', 'icon'), '') || null;
            auth.pin = this.fieldToString(this.getBackupField(item, 'Pin', 'pin'), '') || null;
            auth.algorithm = this.parseBackupHashAlgorithm(this.getBackupField(item, 'Algorithm', 'algorithm'));
            auth.digits = this.fieldToNumber(this.getBackupField(item, 'Digits', 'digits'), 6);
            auth.period = this.fieldToNumber(this.getBackupField(item, 'Period', 'period'), 30);
            auth.counter = this.fieldToNumber(this.getBackupField(item, 'Counter', 'counter'), 0);
            auth.copyCount = this.fieldToNumber(this.getBackupField(item, 'CopyCount', 'copyCount'), 0);
            auth.ranking = this.fieldToNumber(this.getBackupField(item, 'Ranking', 'ranking'), 0);
            if (auth.ranking !== 0) { hasCustomRanking = true; }
            const explicitCategoryId = this.fieldToString(this.getBackupField(item, 'CategoryId', 'categoryId'), '');
            auth.categoryId = explicitCategoryId || secretCategoryMap.get(auth.secret) || null;
            await this.authenticatorService.create(auth);
            addedCount++;
          } catch (err) {
            console.error('Failed to add authenticator:', err);
          }
        }
        if (hasCustomRanking) {
          try {
            const settingsStore = await preferences.getPreferences(
              this.getUIContext().getHostContext() as common.UIAbilityContext,
              'settings_prefs'
            );
            this.currentSortOption = 'custom';
            await settingsStore.put('sortOption', 'custom');
            await settingsStore.flush();
          } catch (_e) {
            this.currentSortOption = 'custom';
          }
        }
        await this.loadAuthenticators();
        await this.loadCategories();
        await this.runAutoBackupIfEnabled();
        this.showToast(`导入成功，添加了 ${addedCount} 个认证器`);
        return;
      }

      // 尝试提取 otpauth:// URI
      const otpPattern = /otpauth:\/\/[^\s"]+/g;
      const matches = content.match(otpPattern);
      if (matches && matches.length > 0) {
        let addedCount = 0;
        for (const uri of matches) {
          try {
            const auth = new Authenticator();
            // 手动解析 URI 参数
            const queryIndex = uri.indexOf('?');
            if (queryIndex >= 0) {
              const queryStr = uri.substring(queryIndex + 1);
              const pairs = queryStr.split('&');
              const paramsMap = new Map<string, string>();
              for (const pair of pairs) {
                const eqIdx = pair.indexOf('=');
                if (eqIdx >= 0) {
                  const key = decodeURIComponent(pair.substring(0, eqIdx));
                  const val = decodeURIComponent(pair.substring(eqIdx + 1));
                  paramsMap.set(key, val);
                }
              }
              auth.secret = paramsMap.get('secret') || '';
              auth.issuer = paramsMap.get('issuer') || '';
              auth.digits = parseInt(paramsMap.get('digits') || '6');
              auth.period = parseInt(paramsMap.get('period') || '30');
            }
            if (auth.secret) {
              await this.authenticatorService.create(auth);
              addedCount++;
            }
          } catch (err) {
            console.error('解析 URI 失败:', err);
          }
        }
        await this.loadAuthenticators();
        await this.runAutoBackupIfEnabled();
        try {
          const prompt = this.getUIContext().getPromptAction();
          prompt.showToast({ message: `导入成功，添加了 ${addedCount} 个认证器`, duration: 1500 });
        } catch (e) {
          console.error('Failed:', e);
        }
        return;
      }

      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '无法识别的文件格式', duration: 1500 });
      } catch (e) {
        console.error('Failed:', e);
      }
    } catch (parseError) {
      console.error('解析失败:', parseError);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '文件格式无效', duration: 1500 });
      } catch (e) {
        console.error('Failed:', e);
      }
    }
  }

  async confirmImportPassword() {
    const pwd = this.importPassword;
    if (!pwd.trim()) {
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '请输入密码', duration: 1500 });
      } catch (e) {
        console.error('Failed to show toast:', e);
      }
      return;
    }

    if (this.pendingEncryptedData && this.pendingEncryptedType) {
      // 有待解密的文件数据
      try {
        const decrypted = await this.backupService.decryptBackup(this.pendingEncryptedData, pwd, this.pendingEncryptedType);
        await this.importFromContent(decrypted);
        this.closeImportPasswordDialog();
      } catch (error) {
        console.error('解密失败:', error);
        try {
          const prompt = this.getUIContext().getPromptAction();
          prompt.showToast({ message: '解密失败或密码错误', duration: 2000 });
        } catch (e) {
          console.error('Failed:', e);
        }
      }
      return;
    }

    this.showToast('请先选择加密备份文件，再输入密码导入');
  }

  private async copyAuthenticatorCode(auth: Authenticator): Promise<void> {
    try {
      const code = await auth.getCodeDefault();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, code);
      await pasteboard.getSystemPasteboard().setData(pasteData);

      auth.copyCount = (auth.copyCount || 0) + 1;
      await this.authenticatorService.update(auth);
      this.applyFilters();
      this.showToast('验证码已复制');
    } catch (error) {
      console.error('复制验证码失败:', error);
      this.showToast('复制验证码失败');
    }
  }

  private async incrementAuthenticatorCounter(auth: Authenticator): Promise<void> {
    try {
      if (auth.type !== AuthenticatorType.Hotp) {
        return;
      }
      auth.counter = (auth.counter || 0) + 1;
      await this.authenticatorService.update(auth);
      await this.loadAuthenticators();
      await this.runAutoBackupIfEnabled();
    } catch (error) {
      console.error('更新计数器失败:', error);
      this.showToast('更新计数器失败');
    }
  }

  /**
   * 删除认证器
   */
  async deleteAuthenticator() {
    if (!this.selectedAuthenticator) return;

    try {
      const id = `${this.selectedAuthenticator.issuer}:${this.selectedAuthenticator.username}:${this.selectedAuthenticator.secret}`;
      await this.authenticatorService.delete(id);
      await this.loadAuthenticators();
      await this.runAutoBackupIfEnabled();
      this.hideEditOptions();
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '删除成功', duration: 1500 });
      } catch (toastError) {
        console.error('Failed to show toast:', toastError);
      }
    } catch (error) {
      console.error('删除认证器失败:', error);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '删除失败', duration: 1500 });
      } catch (toastError) {
        console.error('Failed to show toast:', toastError);
      }
    }
  }


  // ===== MainMenu handlers =====
  onOpenMenu() {
    this.showMainMenu = true;
  }

  onCloseMainMenu() {
    this.showMainMenu = false;
  }

  onBackupClick() {
    this.showMainMenu = false;
    this.showBackupMenu = true;
  }

  async onSettingsClick() {
    this.showMainMenu = false;
    try {
      await this.getUIContext().getRouter().pushUrl({ url: 'pages/Settings' });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`pushUrl failed, code is ${err.code}, message is ${err.message}`);
    }
  }

  async onAboutClick() {
    this.showMainMenu = false;
    try {
      await this.getUIContext().getRouter().pushUrl({ url: 'pages/About' });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`pushUrl failed, code is ${err.code}, message is ${err.message}`);
    }
  }

  async onManageCategories() {
    this.showMainMenu = false;
    try {
      await this.getUIContext().getRouter().pushUrl({ url: 'pages/Categories' });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`pushUrl failed, code is ${err.code}, message is ${err.message}`);
    }
  }

  async onIconPacksClick() {
    this.showMainMenu = false;
    try {
      await this.getUIContext().getRouter().pushUrl({ url: 'pages/IconPacks' });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`pushUrl failed, code is ${err.code}, message is ${err.message}`);
    }
  }

  // ===== Search handlers =====
  toggleSearch() {
    this.showSearchBar = !this.showSearchBar;
    if (!this.showSearchBar) {
      this.searchText = '';
      this.applyFilters();
    }
  }

  backFromSearch() {
    this.showSearchBar = false;
    this.searchText = '';
    this.applyFilters();
  }

  // ===== Sort handlers =====
  toggleSort() {
    this.showSortMenu = true;
  }

  // ===== EditMenu handlers =====
  onEditDetailsFromMenu(auth: Authenticator | null) {
    this.showEditMenu = false;
    if (auth) {
      this.selectedAuthenticator = auth;
      this.editingOriginalId = this.getAuthenticatorId(auth);
      this.showEditDetails = true;
    }
  }

  onEditMenuChangeIcon() {
    this.showEditMenu = false;
    this.showChangeIconSheet = true;
  }

  onEditMenuAssignCategory() {
    this.showEditMenu = false;
    this.showCategorySheet = true;
  }

  onEditMenuShowQr() {
    this.showEditMenu = false;
    this.showQrCodeSheet = true;
  }

  async onSaveIcon(iconKey: string | null) {
    this.showChangeIconSheet = false;
    if (!this.selectedAuthenticator) {
      return;
    }

    let iconToSave = iconKey;
    try {
      // Android parity: selecting a pack icon creates a CustomIcon (@id), not a raw data URI.
      if (iconKey && iconKey.startsWith('iconpack:')) {
        const parsed = this.iconPackService.parseIconKey(iconKey);
        if (parsed) {
          const entry = this.iconPackService.findEntry(parsed.packName, parsed.entryName);
          if (entry && entry.rawBase64) {
            const helper = new util.Base64Helper();
            const bytes = helper.decodeSync(entry.rawBase64);
            iconToSave = await this.customIconService.createFromBytes(bytes);
          } else {
            const source = IconResolver.getService(iconKey);
            if (typeof source === 'string' && source.startsWith('data:image/')) {
              const b64 = source.substring(source.indexOf('base64,') + 7);
              const helper = new util.Base64Helper();
              iconToSave = await this.customIconService.createFromBytes(helper.decodeSync(b64));
            }
          }
        }
      }

      this.selectedAuthenticator.icon = iconToSave;
      await this.authenticatorService.update(this.selectedAuthenticator);
      await this.loadAuthenticators();
      await this.runAutoBackupIfEnabled();
    } catch (err) {
      console.error('更新图标失败:', err);
      this.showToast('更新图标失败');
    }
  }

  async onSaveCategory(category: Category | null) {
    this.showCategorySheet = false;
    if (this.selectedAuthenticator) {
      this.selectedAuthenticator.categoryId = category ? category.id : null;
      try {
        await this.authenticatorService.update(this.selectedAuthenticator);
        await this.loadAuthenticators();
        await this.runAutoBackupIfEnabled();
      } catch (err) {
        console.error('更新分类失败:', err);
      }
    }
  }

  async onEditMenuDelete() {
    this.showEditMenu = false;
    await this.deleteAuthenticator();
  }

  // ===== BackupMenu handlers =====
  onCloseBackupMenu() {
    this.showBackupMenu = false;
  }

  onEncryptedBackup(): void {
    this.showBackupMenu = false;
    this.exportPassword = '';
    this.showExportPasswordDialog = true;
  }

  async confirmExportPassword(): Promise<void> {
    const password = this.exportPassword;
    if (password.trim().length < 4) {
      this.showToast('备份密码至少需要4个字符');
      return;
    }

    try {
      const backupData = await this.backupService.createEncryptedBackupAsync(password);
      this.closeExportPasswordDialog();
      await this.exportBackupContent(backupData, 'stratum', '加密备份创建成功');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('加密备份失败:', error);
      this.showToast(`备份失败: ${message}`, 2000);
    }
  }

  async onHtmlBackup(): Promise<void> {
    this.showBackupMenu = false;
    try {
      const htmlContent = await this.backupService.createHtmlBackupAsync();
      await this.exportBackupContent(htmlContent, 'html', 'HTML备份创建成功');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('HTML备份失败:', error);
      this.showToast(`备份失败: ${message}`, 2000);
    }
  }

  async onUriBackup(): Promise<void> {
    this.showBackupMenu = false;
    try {
      const uriList = await this.backupService.createUriListBackupAsync();
      await this.exportBackupContent(uriList, 'txt', 'URI列表备份创建成功');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('URI列表备份失败:', error);
      this.showToast(`备份失败: ${message}`, 2000);
    }
  }

  onRestoreBackup() {
    this.showBackupMenu = false;
    this.showImportPasswordDialog = false; // Reset dialog state
    this.importFromFile();
  }

  // ===== QrScanner handlers =====
  onCloseQrScanner() {
    this.showQrScanner = false;
  }

  onStartScan() {
    // QrScannerOverlay 现在内部处理扫描
  }

  onSelectImage() {
    // QrScannerOverlay 现在内部处理图片选择
  }

  // ===== EditDetails handlers =====
  onCancelEditDetails() {
    this.showEditDetails = false;
    this.editingOriginalId = null;
  }

  async onSaveEditDetails(auth: Authenticator) {
    this.showEditDetails = false;
    try {
      const newId = this.getAuthenticatorId(auth);
      if (this.editingOriginalId) {
        if (this.editingOriginalId !== newId) {
          await this.authenticatorService.delete(this.editingOriginalId);
          await this.authenticatorService.create(auth);
        } else {
          await this.authenticatorService.update(auth);
        }
      } else {
        await this.authenticatorService.create(auth);
      }

      await this.loadAuthenticators();
      this.editingOriginalId = null;
  await this.runAutoBackupIfEnabled();
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '保存成功', duration: 1500 });
      } catch (e) {
        console.error('Failed:', e);
      }
    } catch (error) {
      console.error('保存失败:', error);
      try {
        const prompt = this.getUIContext().getPromptAction();
        prompt.showToast({ message: '保存失败', duration: 1500 });
      } catch (e) {
        console.error('Failed:', e);
      }
    }
  }

  onBackPress(): boolean {
    if (this.showInputKey) {
      this.showInputKey = false;
      return true;
    }
    if (this.showAddMenu) {
      this.showAddMenu = false;
      return true;
    }
    if (this.showMainMenu) {
      this.showMainMenu = false;
      return true;
    }
    if (this.showBackupMenu) {
      this.showBackupMenu = false;
      return true;
    }
    if (this.showEditMenu) {
      this.showEditMenu = false;
      return true;
    }
    if (this.showEditDetails) {
      this.showEditDetails = false;
      return true;
    }
    if (this.showChangeIconSheet) {
      this.showChangeIconSheet = false;
      return true;
    }
    if (this.showCategorySheet) {
      this.showCategorySheet = false;
      return true;
    }
    if (this.showQrCodeSheet) {
      this.showQrCodeSheet = false;
      return true;
    }
    if (this.showSortMenu) {
      this.showSortMenu = false;
      return true;
    }
    return false;
  }

  /**
   * 构建组件
   */
  build() {
    Stack() {
      // ===== 主内容区 =====
      Column() {
        // 顶部栏（锁定时隐藏，由 PinUnlockSheet 提供解锁界面）
        if (!this.isLocked) {
          TopBar({
            showSearchBar: this.showSearchBar,
            searchText: this.searchText,
            currentCategoryName: this.currentCategoryName,
            colors: this.themeColors,
            onSearchChange: (value: string): void => this.onSearchChange(value),
            onToggleSort: (): void => this.toggleSort(),
            onBackFromSearch: (): void => this.backFromSearch(),
            onToggleSearch: (): void => this.toggleSearch()
          })
        }

        // 认证器列表
        if (this.isLocked) {
          // 解锁界面由 PinUnlockSheet 的遮罩和对话框承担，底层留空避免内容从卡片边缘露出
          Column()
            .width('100%')
            .layoutWeight(1)
        } else if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(this.themeColors.primary)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.filteredAuthenticators.length === 0) {
          Column() {
            EmptyState({
              isSearching: this.searchText.length > 0,
              colors: this.themeColors,
              onGuide: (): void => {
                try {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/Guide' });
                } catch (e) {
                  console.error('导航到指南页失败:', e);
                }
              },
              onImport: (): void => {
                try {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/ImportSource' });
                } catch (e) {
                  console.error('导航到导入页失败:', e);
                }
              },
              onRestore: (): void => { this.importFromFile(); }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 14 }) {
            ForEach(this.filteredAuthenticators, (auth: Authenticator): void => {
              ListItem() {
                AuthenticatorItem({
                  auth: auth,
                  progress: this.progress,
                  isDarkMode: this.isDarkMode,
                  tapToCopy: this.tapToCopy,
                  tapToReveal: this.tapToReveal,
                  tapToRevealDuration: this.tapToRevealDuration,
                  skipToNext: this.skipToNext,
                  codeGroupSize: this.codeGroupSize,
                  showUsernames: this.showUsernames,
                  viewMode: this.viewMode,
                  onItemClick: (): void => {},
                  onCopyCode: (target: Authenticator): void => { this.copyAuthenticatorCode(target); },
                  onIncrementCounter: (target: Authenticator): void => { this.incrementAuthenticatorCounter(target); },
                  onEditClick: (): void => this.showEditOptions(auth)
                })
              }
            }, (auth: Authenticator): string => `${auth.issuer}:${auth.username}:${auth.secret}`)
              .onMove((from: number, to: number): void => {
                if (this.currentSortOption === 'custom' && !this.lockOrdering) {
                  this.onListReorder(from, to);
                }
              })
          }
          .padding({ top: 2, left: 14, right: 14, bottom: 8 })
          .layoutWeight(1)
        }

        if (!this.isLocked) {
          // 底部栏
          BottomBar({
            colors: this.themeColors,
            onOpenMenu: (): void => this.onOpenMenu(),
            onToggleSearch: (): void => this.toggleSearch(),
            onImport: (): void => { this.importFromFile(); },
            onAdd: (): void => { this.showAddMenu = true }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isDarkMode ? this.themeColors.background : '#F6FBFF')

      // ===== 浮层组件 =====

      // 编辑认证器 Sheet
      EditAuthenticatorSheet({
        visible: this.showEditSheet,
        auth: this.selectedAuthenticator,
        colors: { primary: this.themeColors.primary, surface: this.themeColors.surface, background: this.themeColors.background, onBackground: this.themeColors.onBackground },
        onClose: (): void => this.closeEditSheet(),
        onSave: async (auth: Authenticator): Promise<void> => this.handleSaveEdited(auth),
        onDelete: async (auth: Authenticator): Promise<void> => this.handleDeleteFromSheet(auth)
      })

      // 添加菜单 Sheet
      AddMenuSheet({
        visible: this.showAddMenu,
        colors: { primary: this.themeColors.primary, surface: this.themeColors.surface, background: this.themeColors.background, onBackground: this.themeColors.onBackground },
        onClose: (): void => this.closeAddMenu(),
        onScan: (): void => this.handleScan(),
        onEnterKey: (): void => this.handleEnterKey(),
        onRestore: (): void => this.handleRestore(),
        onImport: (): void => this.handleImport()
      })

      // 导入密码对话框
      ImportPasswordDialog({
        visible: this.showImportPasswordDialog,
        colors: { background: this.themeColors.background, surface: this.themeColors.surface, onSurface: this.themeColors.onBackground, border: this.isDarkMode ? '#3A3A3A' : '#E0E0E0' },
        title: '请输入导入密码',
        placeholder: '密码',
        confirmText: '导入',
        password: this.importPassword,
        onChange: (v: string) => { this.importPassword = v },
        onCancel: (): void => this.closeImportPasswordDialog(),
        onConfirm: (): void => { this.confirmImportPassword(); }
      })

      // 导出密码对话框
      ImportPasswordDialog({
        visible: this.showExportPasswordDialog,
        colors: { background: this.themeColors.background, surface: this.themeColors.surface, onSurface: this.themeColors.onBackground, border: this.isDarkMode ? '#3A3A3A' : '#E0E0E0' },
        title: '设置备份密码',
        placeholder: '至少4个字符',
        confirmText: '导出',
        password: this.exportPassword,
        onChange: (v: string) => { this.exportPassword = v },
        onCancel: (): void => this.closeExportPasswordDialog(),
        onConfirm: (): void => { this.confirmExportPassword(); }
      })

      // PIN 解锁 Sheet
      PinUnlockSheet({
        visible: this.showPinSheet,
        colors: {
          primary: this.themeColors.primary,
          surface: this.themeColors.surface,
          background: this.themeColors.background,
          onBackground: this.themeColors.onBackground,
          textSecondary: this.themeColors.textSecondary,
          onPrimary: this.themeColors.onPrimary,
          border: this.isDarkMode ? '#3A3A3A' : '#E0E0E0'
        },
        allowBiometrics: this.allowBiometricUnlock && this.biometricSupported,
        isLoading: this.isUnlocking,
        errorMessage: this.unlockError,
        onBiometric: (): void => this.tryBiometricUnlock(),
        onCancel: (): void => { this.showPinSheet = true; },
        onConfirm: (pin: string): void => this.onPinConfirm(pin)
      })

      // 首次密码设置对话框
      PasswordSetupDialog({
        visible: this.showPasswordSetup,
        colors: this.themeColors, // Add this
        onSetPassword: (password: string): void => { this.onPasswordSetup(password); },
        onSkip: (): void => { this.onSkipPasswordSetup(); }
      })

      // 主菜单
      MainMenu({
        visible: this.showMainMenu,
        categories: this.categories,
        selectedCategoryId: this.selectedCategoryId,
        showUncategorized: this.showUncategorized,
        colors: this.themeColors,
        onSelectCategory: (id: string | null): void => { this.onSelectCategory(id); },
        onManageCategories: (): void => { this.onManageCategories(); },
        onIconPacksClick: (): void => { this.onIconPacksClick(); },
        onBackupClick: (): void => this.onBackupClick(),
        onSettingsClick: (): void => { this.onSettingsClick(); },
        onAboutClick: (): void => { this.onAboutClick(); },
        onClose: (): void => this.onCloseMainMenu()
      })

      // 排序菜单
      SortMenu({
        visible: this.showSortMenu,
        currentSortOption: this.currentSortOption,
        lockOrdering: this.lockOrdering,
        colors: this.themeColors,
        onSort: (option: string): void => this.onSortChange(option),
        onToggleLockOrdering: (): void => { this.onToggleLockOrdering(); },
        onCancel: (): void => { this.showSortMenu = false }
      })

      // 编辑操作菜单
      EditMenu({
        visible: this.showEditMenu,
        authenticator: this.selectedAuthenticator,
        colors: this.themeColors,
        onEditDetails: (auth: Authenticator | null): void => this.onEditDetailsFromMenu(auth),
        onChangeIcon: (): void => this.onEditMenuChangeIcon(),
        onAssignCategory: (): void => this.onEditMenuAssignCategory(),
        onShowQrCode: (): void => this.onEditMenuShowQr(),
        onDelete: (): void => { this.onEditMenuDelete(); },
        onCancel: (): void => this.hideEditOptions()
      })

      // 备份菜单
      BackupMenu({
        colors: this.getColors(),
        visible: this.showBackupMenu,
        onEncryptedBackup: (): void => { this.onEncryptedBackup(); },
        onHtmlBackup: (): void => { this.onHtmlBackup(); },
        onUriBackup: (): void => { this.onUriBackup(); },
        onRestoreBackup: (): void => this.onRestoreBackup(),
        onClose: (): void => this.onCloseBackupMenu()
      })

      // QR 扫描覆盖层
      QrScannerOverlay({
        visible: this.showQrScanner,
        colors: this.themeColors,
        onClose: (): void => this.onCloseQrScanner(),
        onScanResult: (count: number): void => {
          this.showQrScanner = false;
          this.loadAuthenticators();
          this.runAutoBackupIfEnabled();
        }
      })

      // 编辑详情面板
      EditDetails({
        visible: this.showEditDetails,
        authenticator: this.selectedAuthenticator,
        colors: this.themeColors,
        onCancel: (): void => this.onCancelEditDetails(),
        onSave: (auth: Authenticator): void => { this.onSaveEditDetails(auth); }
      })

      // 手动输入密钥面板
      InputOTPKey({
        visible: this.showInputKey,
        onCancel: (): void => { this.showInputKey = false; },
        onSave: (auth: Authenticator): void => {
          this.showInputKey = false;
          this.onSaveEditDetails(auth);
        }
      })

      // 更改图标面板
      ChangeIconSheet({
        visible: this.showChangeIconSheet,
        currentIcon: this.selectedAuthenticator ? this.selectedAuthenticator.icon : null,
        colors: this.themeColors,
        onClose: (): void => { this.showChangeIconSheet = false; },
        onSelect: (key: string | null): void => { this.onSaveIcon(key); }
      })

      // 分类选择面板
      CategorySheet({
        visible: this.showCategorySheet,
        categories: this.categories,
        colors: this.themeColors,
        onClose: (): void => { this.showCategorySheet = false; },
        onSelect: (cat: Category | null): void => { this.onSaveCategory(cat); }
      })

      // 二维码面板
      QrCodeSheet({
        visible: this.showQrCodeSheet,
        authenticator: this.selectedAuthenticator,
        colors: this.themeColors,
        onClose: (): void => { this.showQrCodeSheet = false; }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private getAuthenticatorId(auth: Authenticator): string {
    return `${auth.issuer}:${auth.username}:${auth.secret}`;
  }
}
