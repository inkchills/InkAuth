// ImportSource.ets - 从其他应用导入页面

import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { UriBytesReader } from '../core/util/UriBytesReader';
import preferences from '@ohos.data.preferences';
import { ThemeManager, ThemeColors } from '../core/util/ThemeManager';
import { AuthenticatorService } from '../core/service/impl/AuthenticatorService';
import { CategoryService } from '../core/service/impl/CategoryService';
import { BackupService } from '../core/service/impl/BackupService';
import { CustomIconService } from '../core/service/impl/CustomIconService';
import { Authenticator } from '../core/entity/Authenticator';
import { Category } from '../core/entity/Category';
import { AuthenticatorType } from '../core/AuthenticatorType';
import { HashAlgorithm } from '../core/generator/HashAlgorithm';
import { UriParser } from '../core/UriParser';
import { IconResolver } from '../core/util/IconResolver';
import { SecretUtil } from '../core/util/SecretUtil';
import { ThirdPartyCrypto } from '../core/util/ThirdPartyCrypto';
import { decryptKeePassKdbx } from '../core/util/KeePassKdbx';
import { util } from '@kit.ArkTS';
import { ImportPasswordDialog } from './index/components/ImportPasswordDialog';

interface ImportSourceItem {
  id: string;
  name: string;
  icon: string;
  hint: string;
  isGuideOnly: boolean;
  fileFilter: string[];
}

@Entry
@Component
struct ImportSource {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private authenticatorService: AuthenticatorService = AuthenticatorService.getInstance();
  private categoryService: CategoryService = CategoryService.getInstance();
  private backupService: BackupService = new BackupService();
  private iconResolver: IconResolver = new IconResolver();
  @StorageProp('insetTopPx') insetTopPx: number = 0;
  @State private showImportPasswordDialog: boolean = false;
  @State private importPassword: string = '';
  private pendingEncryptedData: Uint8Array | null = null;
  private pendingEncryptedType: string | null = null;
  private pendingEncryptedSourceId: string | null = null;
  private pendingTwoFasPayload: string | null = null;
  private pendingTwoFasGroups: Array<Record<string, Object>> = [];
  private pendingJsonPayload: string | null = null;

  @State private sources: ImportSourceItem[] = [
    {
      id: 'googleauthenticator',
      name: 'Google Authenticator',
      icon: 'ic_googleauthenticator',
      hint: '使用 Google Authenticator 的导出/转移功能，扫描屏幕上的二维码进行导入。',
      isGuideOnly: true,
      fileFilter: []
    },
    {
      id: 'andotp',
      name: 'andOTP',
      icon: 'ic_andotp',
      hint: '选择 otp_accounts.json（明文）或加密备份文件。',
      isGuideOnly: false,
      fileFilter: ['JSON|.json']
    },
    {
      id: 'freeotp',
      name: 'FreeOTP',
      icon: 'ic_freeotp',
      hint: 'FreeOTP 的 externalBackup.xml 需要额外密码解密，鸿蒙端暂未支持；请先使用 Android 版或导出 otpauth URI。',
      isGuideOnly: true,
      fileFilter: []
    },
    {
      id: 'freeotpplus',
      name: 'FreeOTP+',
      icon: 'ic_freeotpplus',
      hint: '选择 freeotp-backup.json。',
      isGuideOnly: false,
      fileFilter: ['JSON|.json']
    },
    {
      id: 'aegis',
      name: 'Aegis',
      icon: 'ic_aegis',
      hint: '选择 aegis-export.json（明文或加密）。',
      isGuideOnly: false,
      fileFilter: ['JSON|.json']
    },
    {
      id: 'bitwarden',
      name: 'Bitwarden',
      icon: 'ic_bitwarden',
      hint: '选择 bitwarden_export.json（明文或加密）。',
      isGuideOnly: false,
      fileFilter: ['JSON|.json']
    },
    {
      id: 'enteauth',
      name: 'Ente Auth',
      icon: 'ic_enteauth',
      hint: '选择 ente-auth-codes.txt 或加密备份。',
      isGuideOnly: false,
      fileFilter: ['Text|.txt', 'JSON|.json']
    },
    {
      id: 'protonauthenticator',
      name: 'Proton Authenticator',
      icon: 'ic_protonauthenticator',
      hint: '选择 proton_authenticator_backup.json。',
      isGuideOnly: false,
      fileFilter: ['JSON|.json']
    },
    {
      id: 'winauth',
      name: 'WinAuth',
      icon: 'ic_winauth',
      hint: '选择 winauth.txt；加密 zip 暂未在鸿蒙端支持。',
      isGuideOnly: false,
      fileFilter: ['Text|.txt']
    },
    {
      id: 'twofas',
      name: '2FAS',
      icon: 'ic_twofas',
      hint: '选择 2fas-backup.2fas（明文或加密）。',
      isGuideOnly: false,
      fileFilter: ['2FAS|.2fas', 'JSON|.json']
    },
    {
      id: 'keepass',
      name: 'KeePass',
      icon: 'ic_keepass',
      hint: '支持 KeePass KDBX 4（需主密码）以及含 otpauth:// 的 XML/CSV/文本导出。',
      isGuideOnly: false,
      fileFilter: ['KDBX|.kdbx', 'XML|.xml', 'CSV|.csv', 'Text|.txt']
    },
    {
      id: 'lastpass',
      name: 'LastPass',
      icon: 'ic_lastpass',
      hint: '从 LastPass Authenticator 导出备份文件。',
      isGuideOnly: false,
      fileFilter: ['JSON|.json']
    },
    {
      id: 'authy',
      name: 'Authy',
      icon: 'ic_authy',
      hint: 'Authy 不支持直接导出。请参考指南了解如何从 Authy 提取令牌。',
      isGuideOnly: true,
      fileFilter: []
    },
    {
      id: 'totpauthenticator',
      name: 'TOTP Authenticator',
      icon: 'ic_totpauthenticator',
      hint: 'TOTP Authenticator 的 TOTP_Backup.encrypt 需要密码解密，鸿蒙端暂未支持。',
      isGuideOnly: true,
      fileFilter: []
    },
    {
      id: 'authenticatorplus',
      name: 'Authenticator Plus',
      icon: 'ic_authenticatorplus',
      hint: 'Authenticator Plus 导出数据库需要 SQLCipher 兼容解密，鸿蒙端暂未支持。',
      isGuideOnly: true,
      fileFilter: []
    },
    {
      id: 'steam',
      name: 'Steam',
      icon: 'ic_steam',
      hint: 'Steam 令牌需要从 SteamGuard 文件中提取。请参考指南了解详细步骤。',
      isGuideOnly: true,
      fileFilter: []
    },
    {
      id: 'blizzard',
      name: 'Blizzard Authenticator',
      icon: 'ic_blizzard',
      hint: '从 Blizzard Authenticator 数据文件中导入。',
      isGuideOnly: true,
      fileFilter: []
    },
    {
      id: 'urilist',
      name: 'URI 列表',
      icon: 'baseline_list_24',
      hint: '导入包含 otpauth:// URI 的文本文件，每行一个 URI。',
      isGuideOnly: false,
      fileFilter: ['Text|.txt']
    }
  ];

  getColors(): ThemeColors {
    return this.themeManager.getColors();
  }

  private async pickAndImportFile(source: ImportSourceItem): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.authenticatorService.initialize(context);
      await this.categoryService.initialize(context);
      await CustomIconService.getInstance().initialize(context);

      const documentViewPicker = new picker.DocumentViewPicker(context);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;

      if (source.fileFilter.length > 0) {
        documentSelectOptions.fileSuffixFilters = source.fileFilter;
      } else {
        documentSelectOptions.fileSuffixFilters = ['All|.*'];
      }

      const uris = await documentViewPicker.select(documentSelectOptions);
      if (!uris || uris.length === 0) {
        return;
      }

      const uri = uris[0];
      const data = await this.readFileBytesFromUri(uri);
      if (this.isStrongEncrypted(data)) {
        this.pendingEncryptedData = data;
        this.pendingEncryptedType = 'strong';
        this.pendingEncryptedSourceId = 'stratum';
        this.showImportPasswordDialog = true;
        return;
      }
      if (this.isLegacyEncrypted(data)) {
        this.pendingEncryptedData = data;
        this.pendingEncryptedType = 'legacy';
        this.pendingEncryptedSourceId = 'stratum';
        this.showImportPasswordDialog = true;
        return;
      }

      // andOTP: try plain JSON first; otherwise treat as encrypted binary
      if (source.id === 'andotp') {
        try {
          const content = this.bytesToString(data);
          const parsed = JSON.parse(content) as Object;
          if (Array.isArray(parsed)) {
            await this.importAndOtpAccounts(parsed as Array<Record<string, Object>>);
            return;
          }
        } catch (_e) {
          // fall through to encrypted path
        }
        this.pendingEncryptedData = data;
        this.pendingEncryptedType = 'andotp';
        this.pendingEncryptedSourceId = 'andotp';
        this.showImportPasswordDialog = true;
        return;
      }

      // KeePass: KDBX binary always needs a password; XML/CSV/text fall through
      if (source.id === 'keepass' && this.isKeePassKdbx(data)) {
        this.pendingEncryptedData = data;
        this.pendingEncryptedType = 'keepass';
        this.pendingEncryptedSourceId = 'keepass';
        this.showImportPasswordDialog = true;
        return;
      }

      const content = this.bytesToString(data);
      await this.importContent(content, source.id);
    } catch (error) {
      console.error('导入失败:', error);
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({
        message: '导入失败: ' + (error instanceof Error ? error.message : String(error)),
        duration: 2000
      });
    }
  }

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

  private closeImportPasswordDialog(): void {
    this.showImportPasswordDialog = false;
    this.importPassword = '';
    this.pendingEncryptedData = null;
    this.pendingEncryptedType = null;
    this.pendingEncryptedSourceId = null;
    this.pendingTwoFasPayload = null;
    this.pendingTwoFasGroups = [];
    this.pendingJsonPayload = null;
  }

  private isKeePassKdbx(data: Uint8Array): boolean {
    // KeePass signature1 = 0x9AA2D903 (little-endian)
    return data.length >= 8 &&
      data[0] === 0x03 && data[1] === 0xD9 && data[2] === 0xA2 && data[3] === 0x9A &&
      data[4] === 0x67 && data[5] === 0xFB && data[6] === 0x4B && data[7] === 0xB5;
  }

  private requestJsonPassword(encType: string, sourceId: string, jsonPayload: string): void {
    this.pendingEncryptedType = encType;
    this.pendingEncryptedSourceId = sourceId;
    this.pendingJsonPayload = jsonPayload;
    this.showImportPasswordDialog = true;
  }

  private async confirmImportPassword(): Promise<void> {
    const password = this.importPassword;
    if (!password.trim()) {
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '请输入密码', duration: 1500 });
      return;
    }

    const encType = this.pendingEncryptedType;
    try {
      if (encType === 'andotp' && this.pendingEncryptedData) {
        const decrypted = await ThirdPartyCrypto.decryptAndOtp(this.pendingEncryptedData, password);
        this.closeImportPasswordDialog();
        const accounts = JSON.parse(decrypted) as Array<Record<string, Object>>;
        if (!Array.isArray(accounts)) {
          throw new Error('解密后不是 andOTP 账户数组');
        }
        await this.importAndOtpAccounts(accounts);
        return;
      }

      if (encType === 'twofas' && this.pendingTwoFasPayload) {
        const decrypted = await ThirdPartyCrypto.decryptTwoFas(this.pendingTwoFasPayload, password);
        const services = JSON.parse(decrypted) as Array<Record<string, Object>>;
        const groups = this.pendingTwoFasGroups;
        this.closeImportPasswordDialog();
        await this.importTwoFasBackup(services, groups);
        return;
      }

      if (encType === 'aegis' && this.pendingJsonPayload) {
        const decrypted = await ThirdPartyCrypto.decryptAegis(this.pendingJsonPayload, password);
        this.closeImportPasswordDialog();
        const database = JSON.parse(decrypted) as Record<string, Object>;
        const entries = database['entries'] as Array<Record<string, Object>> | undefined;
        if (!Array.isArray(entries)) {
          throw new Error('解密后的 Aegis 数据库缺少 entries');
        }
        await this.importAegisEntries(entries);
        return;
      }

      if (encType === 'bitwarden' && this.pendingJsonPayload) {
        const decrypted = await ThirdPartyCrypto.decryptBitwarden(this.pendingJsonPayload, password);
        this.closeImportPasswordDialog();
        const vault = JSON.parse(decrypted) as Record<string, Object>;
        const items = Array.isArray(vault['items']) ? vault['items'] as Array<Record<string, Object>> : [];
        const folders = Array.isArray(vault['folders']) ? vault['folders'] as Array<Record<string, Object>> : [];
        await this.importBitwardenVault(items, folders);
        return;
      }

      if (encType === 'enteauth' && this.pendingJsonPayload) {
        const decrypted = await ThirdPartyCrypto.decryptEnte(this.pendingJsonPayload, password);
        this.closeImportPasswordDialog();
        await this.importUriText(decrypted);
        return;
      }

      if (encType === 'keepass' && this.pendingEncryptedData) {
        const uris = await decryptKeePassKdbx(this.pendingEncryptedData, password);
        this.closeImportPasswordDialog();
        await this.importUriListFromArray(uris);
        return;
      }

      if (!this.pendingEncryptedData || !encType) {
        this.closeImportPasswordDialog();
        return;
      }

      const decrypted = await this.backupService.decryptBackup(this.pendingEncryptedData, password, encType);
      this.closeImportPasswordDialog();
      await this.importContent(decrypted, 'stratum');
    } catch (error) {
      console.error('解密导入失败:', error);
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '解密失败或密码错误', duration: 2000 });
    }
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

  private normalizeSecret(value: string, type: AuthenticatorType = AuthenticatorType.Totp): string {
    const cleaned = value.replace(/\s/g, '').replace(/=/g, '').toUpperCase();
    if (type === AuthenticatorType.MobileOtp) {
      return cleaned;
    }
    return cleaned;
  }

  private signedByteArrayToBytes(value: Object | undefined): Uint8Array {
    if (!Array.isArray(value)) {
      return new Uint8Array();
    }
    const bytes: number[] = [];
    for (const item of value as Array<number>) {
      const numeric = Number(item);
      bytes.push(numeric < 0 ? numeric + 256 : numeric);
    }
    return new Uint8Array(bytes);
  }

  private mapAlgorithm(value: Object | undefined): HashAlgorithm {
    const text = this.fieldToString(value, 'SHA1').toUpperCase();
    if (text === 'SHA256') return HashAlgorithm.Sha256;
    if (text === 'SHA512') return HashAlgorithm.Sha512;
    return HashAlgorithm.Sha1;
  }

  private mapOtpType(value: Object | undefined): AuthenticatorType {
    const text = this.fieldToString(value, 'TOTP').toUpperCase();
    if (text === 'HOTP') return AuthenticatorType.Hotp;
    if (text === 'STEAM') return AuthenticatorType.SteamOtp;
    if (text === 'MOTP' || text === 'MOBILEOTP') return AuthenticatorType.MobileOtp;
    if (text === 'YANDEX' || text === 'YAOTP') return AuthenticatorType.YandexOtp;
    return AuthenticatorType.Totp;
  }

  private async ensureCategory(name: string): Promise<string | null> {
    const trimmed = name.trim();
    if (!trimmed) {
      return null;
    }
    const existing = (await this.categoryService.getAll()).find((item: Category): boolean => item.name === trimmed);
    if (existing) {
      return existing.id;
    }
    const category = new Category(trimmed);
    try {
      await this.categoryService.create(category);
    } catch (_error) {
      const fallback = (await this.categoryService.getAll()).find((item: Category): boolean => item.name === trimmed);
      return fallback ? fallback.id : null;
    }
    return category.id;
  }

  private parseBackupAuthenticatorType(value: Object | undefined): AuthenticatorType {
    const text = this.fieldToString(value, '').toLowerCase();
    if (text === 'hotp') return AuthenticatorType.Hotp;
    if (text === 'totp') return AuthenticatorType.Totp;
    if (text === 'mobileotp' || text === 'motp') return AuthenticatorType.MobileOtp;
    if (text === 'steamotp' || text === 'steam') return AuthenticatorType.SteamOtp;
    if (text === 'yandexotp' || text === 'yaotp') return AuthenticatorType.YandexOtp;

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
      default:
        return AuthenticatorType.Totp;
    }
  }

  private parseBackupHashAlgorithm(value: Object | undefined): HashAlgorithm {
    const text = this.fieldToString(value, '').toLowerCase();
    if (text === 'sha256') return HashAlgorithm.Sha256;
    if (text === 'sha512') return HashAlgorithm.Sha512;
    return this.fieldToNumber(value, HashAlgorithm.Sha1) as HashAlgorithm;
  }

  private async importContent(content: string, sourceId: string): Promise<void> {
    try {
      if (sourceId === 'urilist' || sourceId === 'winauth' || sourceId === 'keepass') {
        await this.importUriText(content);
        return;
      }

      // 尝试 JSON 格式
      const parsed = JSON.parse(content) as Record<string, Object>;

      if (await this.importJsonBySource(parsed, sourceId)) {
        return;
      }

      // Stratum/AuthenticatorPro 格式
      const categoriesValue = parsed['Categories'] || parsed['categories'];
      const bindingsValue = parsed['AuthenticatorCategories'] || parsed['authenticatorCategories'];
      const secretCategoryMap: Map<string, string> = new Map();
      if (Array.isArray(categoriesValue)) {
        for (const categoryItem of categoriesValue as Array<Record<string, Object>>) {
          const name = this.fieldToString(this.getBackupField(categoryItem, 'Name', 'name'), '').trim();
          if (!name) {
            continue;
          }
          const id = this.fieldToString(this.getBackupField(categoryItem, 'Id', 'id'), `${name}_${Date.now()}`);
          const ranking = this.fieldToNumber(this.getBackupField(categoryItem, 'Ranking', 'ranking'), 0);
          try {
            await this.categoryService.create(new Category(name, id, ranking));
          } catch (err) {
            console.error('导入分类失败:', err);
          }
        }
      }
      if (Array.isArray(bindingsValue)) {
        for (const bindingItem of bindingsValue as Array<Record<string, Object>>) {
          const secret = this.fieldToString(this.getBackupField(bindingItem, 'AuthenticatorSecret', 'authenticatorSecret'), '');
          const categoryId = this.fieldToString(this.getBackupField(bindingItem, 'CategoryId', 'categoryId'), '');
          if (secret && categoryId) {
            secretCategoryMap.set(secret, categoryId);
          }
        }
      }

      const customIconsValue = parsed['CustomIcons'] || parsed['customIcons'];
      if (Array.isArray(customIconsValue)) {
        try {
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          const customIconService = CustomIconService.getInstance();
          await customIconService.initialize(context);
          await customIconService.importFromBackup(customIconsValue as Array<Record<string, Object>>);
        } catch (err) {
          console.error('导入自定义图标失败:', err);
        }
      }

      const authsValue = parsed['Authenticators'] || parsed['authenticators'];
      const auths = Array.isArray(authsValue) ? authsValue as Array<Record<string, Object>> : undefined;
      if (Array.isArray(auths)) {
        await this.importAuthenticatorArray(auths, secretCategoryMap);
        return;
      }

      // Aegis 格式（加密：db 为 base64 字符串；明文：db.entries）
      if (typeof parsed['db'] === 'string') {
        this.requestJsonPassword('aegis', 'aegis', content);
        return;
      }
      const db = parsed['db'] as Record<string, Object> | undefined;
      if (db) {
        const entries = db['entries'] as Array<Record<string, Object>> | undefined;
        if (Array.isArray(entries)) {
          await this.importAegisEntries(entries);
          return;
        }
      }

      // 2FAS 格式
      const encrypted2fas = this.fieldToString(parsed['servicesEncrypted'], '');
      if (encrypted2fas) {
        this.pendingEncryptedType = 'twofas';
        this.pendingEncryptedSourceId = 'twofas';
        this.pendingTwoFasPayload = encrypted2fas;
        this.pendingTwoFasGroups = Array.isArray(parsed['groups'])
          ? parsed['groups'] as Array<Record<string, Object>>
          : [];
        this.showImportPasswordDialog = true;
        return;
      }
      const services = parsed['services'] as Array<Record<string, Object>> | undefined;
      if (Array.isArray(services)) {
        const groups = Array.isArray(parsed['groups']) ? parsed['groups'] as Array<Record<string, Object>> : [];
        await this.importTwoFasBackup(services, groups);
        return;
      }

      // Bitwarden 加密导出
      if (parsed['encrypted'] === true) {
        this.requestJsonPassword('bitwarden', 'bitwarden', content);
        return;
      }

      // Ente Auth 加密备份
      if (parsed['encryptedData']) {
        this.requestJsonPassword('enteauth', 'enteauth', content);
        return;
      }

      // Bitwarden / Ente Auth 明文格式
      const items = parsed['items'] as Array<Record<string, Object>> | undefined;
      if (Array.isArray(items)) {
        const looksLikeBitwarden = items.some((item: Record<string, Object>): boolean => {
          const login = item['login'] as Record<string, Object> | undefined;
          return !!login && !!login['totp'];
        });
        if (looksLikeBitwarden) {
          const folders = Array.isArray(parsed['folders']) ? parsed['folders'] as Array<Record<string, Object>> : [];
          await this.importBitwardenVault(items, folders);
        } else {
          await this.importEnteAuthItems(items);
        }
        return;
      }

      // Ente Auth 格式
      const enteItems = parsed['data'] as Array<Record<string, Object>> | undefined;
      if (Array.isArray(enteItems)) {
        await this.importEnteAuthItems(enteItems);
        return;
      }

      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '无法识别的文件格式', duration: 1500 });
    } catch (_parseErr) {
      await this.importUriText(content);
    }
  }

  private async importJsonBySource(parsed: Record<string, Object>, sourceId: string): Promise<boolean> {
    switch (sourceId) {
      case 'andotp': {
        if (Array.isArray(parsed as Object)) {
          await this.importAndOtpAccounts(parsed as Object as Array<Record<string, Object>>);
          return true;
        }
        break;
      }
      case 'freeotpplus': {
        const tokens = parsed['tokens'];
        if (Array.isArray(tokens)) {
          await this.importFreeOtpPlusTokens(tokens as Array<Record<string, Object>>);
          return true;
        }
        break;
      }
      case 'protonauthenticator': {
        const entries = parsed['entries'];
        if (Array.isArray(entries)) {
          await this.importProtonEntries(entries as Array<Record<string, Object>>);
          return true;
        }
        break;
      }
      case 'twofas': {
        const encrypted = this.fieldToString(parsed['servicesEncrypted'], '');
        if (encrypted) {
          this.pendingEncryptedType = 'twofas';
          this.pendingEncryptedSourceId = 'twofas';
          this.pendingTwoFasPayload = encrypted;
          this.pendingTwoFasGroups = Array.isArray(parsed['groups'])
            ? parsed['groups'] as Array<Record<string, Object>>
            : [];
          this.showImportPasswordDialog = true;
          return true;
        }
        const services = parsed['services'];
        if (Array.isArray(services)) {
          const groups = Array.isArray(parsed['groups']) ? parsed['groups'] as Array<Record<string, Object>> : [];
          await this.importTwoFasBackup(services as Array<Record<string, Object>>, groups);
          return true;
        }
        break;
      }
      case 'aegis': {
        if (typeof parsed['db'] === 'string') {
          this.requestJsonPassword('aegis', 'aegis', JSON.stringify(parsed));
          return true;
        }
        const db = parsed['db'] as Record<string, Object> | undefined;
        const entries = db ? db['entries'] as Array<Record<string, Object>> | undefined : undefined;
        if (Array.isArray(entries)) {
          await this.importAegisEntries(entries);
          return true;
        }
        break;
      }
      case 'bitwarden': {
        if (parsed['encrypted'] === true) {
          this.requestJsonPassword('bitwarden', 'bitwarden', JSON.stringify(parsed));
          return true;
        }
        const items = parsed['items'];
        if (Array.isArray(items)) {
          const folders = Array.isArray(parsed['folders']) ? parsed['folders'] as Array<Record<string, Object>> : [];
          await this.importBitwardenVault(items as Array<Record<string, Object>>, folders);
          return true;
        }
        break;
      }
      case 'enteauth': {
        if (parsed['encryptedData']) {
          this.requestJsonPassword('enteauth', 'enteauth', JSON.stringify(parsed));
          return true;
        }
        await this.importEnteAuthBackup(parsed);
        return true;
      }
      case 'lastpass': {
        const accounts = parsed['accounts'];
        if (Array.isArray(accounts)) {
          const folders = Array.isArray(parsed['folders']) ? parsed['folders'] as Array<Record<string, Object>> : [];
          await this.importLastPassBackup(accounts as Array<Record<string, Object>>, folders);
          return true;
        }
        break;
      }
      case 'freeotp':
      case 'totpauthenticator':
      case 'authenticatorplus':
      case 'blizzard':
        this.showUnsupported('该应用的原生备份格式暂未在鸿蒙端支持，请先转换为 otpauth URI 列表或 InkAuth 备份。');
        return true;
    }
    return false;
  }

  private showUnsupported(message: string): void {
    const prompt = this.getUIContext().getPromptAction();
    prompt.showToast({ message, duration: 3000 });
  }

  private async importAuthenticatorArray(auths: Array<Record<string, Object>>, secretCategoryMap?: Map<string, string>): Promise<void> {
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
        if (auth.ranking !== 0) {
          hasCustomRanking = true;
        }
        const explicitCategoryId = this.fieldToString(this.getBackupField(item, 'CategoryId', 'categoryId'), '');
        auth.categoryId = explicitCategoryId || (secretCategoryMap ? secretCategoryMap.get(auth.secret) || null : null);
        if (auth.issuer) {
          auth.icon = IconResolver.findServiceKeyByName(auth.issuer);
        }
        if (auth.secret) {
          await this.authenticatorService.create(auth);
          addedCount++;
        }
      } catch (err) {
        console.error('Failed to add authenticator:', err);
      }
    }
    if (hasCustomRanking) {
      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const settingsStore = await preferences.getPreferences(context, 'settings_prefs');
        await settingsStore.put('sortOption', 'custom');
        await settingsStore.flush();
      } catch (_e) {
        // Index will pick up on next launch; best-effort here
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importAndOtpAccounts(accounts: Array<Record<string, Object>>): Promise<void> {
    let addedCount = 0;
    for (const account of accounts) {
      try {
        const type = this.mapOtpType(account['type']);
        const issuerRaw = this.fieldToString(account['issuer'], '');
        const labelRaw = this.fieldToString(account['label'], '');
        const thumbnail = this.fieldToString(account['thumbnail'], issuerRaw);
        const auth = new Authenticator();
        auth.type = type;
        auth.secret = this.normalizeSecret(this.fieldToString(account['secret'], ''), type);
        auth.issuer = issuerRaw || labelRaw;
        auth.username = issuerRaw ? labelRaw : null;
        auth.digits = this.fieldToNumber(account['digits'], type === AuthenticatorType.SteamOtp ? 5 : 6);
        auth.period = this.fieldToNumber(account['period'], 30);
        auth.counter = this.fieldToNumber(account['counter'], 0);
        auth.algorithm = this.mapAlgorithm(account['algorithm']);
        auth.icon = IconResolver.findServiceKeyByName(thumbnail || auth.issuer || '');

        const tags = Array.isArray(account['tags']) ? account['tags'] as Array<string> : [];
        if (tags.length > 0) {
          auth.categoryId = await this.ensureCategory(String(tags[0]));
        }

        if (auth.secret) {
          await this.authenticatorService.create(auth);
          addedCount++;
        }
      } catch (error) {
        console.error('andOTP import error:', error);
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importFreeOtpPlusTokens(tokens: Array<Record<string, Object>>): Promise<void> {
    let addedCount = 0;
    for (const token of tokens) {
      try {
        const type = this.mapOtpType(token['type']);
        const issuer = this.fieldToString(token['issuerExt'], '') || this.fieldToString(token['label'], '');
        const secretBytes = this.signedByteArrayToBytes(token['secret']);
        const auth = new Authenticator();
        auth.type = type;
        auth.secret = secretBytes.length > 0 ? SecretUtil.bytesToBase32(secretBytes) : this.normalizeSecret(this.fieldToString(token['secret'], ''), type);
        auth.issuer = issuer;
        auth.username = this.fieldToString(token['issuerExt'], '') ? this.fieldToString(token['label'], '') : null;
        auth.digits = this.fieldToNumber(token['digits'], 6);
        auth.period = this.fieldToNumber(token['period'], 30);
        auth.counter = this.fieldToNumber(token['counter'], 0);
        auth.algorithm = this.mapAlgorithm(token['algo']);
        auth.icon = IconResolver.findServiceKeyByName(auth.issuer || '');

        if (auth.secret) {
          await this.authenticatorService.create(auth);
          addedCount++;
        }
      } catch (error) {
        console.error('FreeOTP+ import error:', error);
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importProtonEntries(entries: Array<Record<string, Object>>): Promise<void> {
    let addedCount = 0;
    for (const entry of entries) {
      try {
        const content = entry['content'] as Record<string, Object> | undefined;
        if (!content) {
          continue;
        }
        const entryType = this.fieldToString(content['entry_type'], 'Totp');
        const name = this.fieldToString(content['name'], '');
        const uri = this.fieldToString(content['uri'], '');

        if (entryType === 'Totp' && uri.startsWith('otpauth://')) {
          const parsed = UriParser.parseStandardUri(uri, this.iconResolver).authenticator;
          if ((!parsed.username && parsed.issuer !== name) || (parsed.username && parsed.username !== name)) {
            parsed.username = name;
          }
          await this.authenticatorService.create(parsed);
          addedCount++;
        } else if (entryType === 'Steam' && uri.startsWith('steam://')) {
          const auth = new Authenticator();
          auth.type = AuthenticatorType.SteamOtp;
          auth.issuer = name || 'Steam';
          auth.username = null;
          auth.secret = this.normalizeSecret(uri.substring('steam://'.length), AuthenticatorType.SteamOtp);
          auth.digits = 5;
          auth.period = 30;
          auth.algorithm = HashAlgorithm.Sha1;
          auth.icon = IconResolver.findServiceKeyByName(auth.issuer);
          await this.authenticatorService.create(auth);
          addedCount++;
        }
      } catch (error) {
        console.error('Proton Authenticator import error:', error);
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importTwoFasBackup(services: Array<Record<string, Object>>, groups: Array<Record<string, Object>>): Promise<void> {
    const groupNameById: Map<string, string> = new Map();
    for (const group of groups) {
      const id = this.fieldToString(group['id'], '');
      const name = this.fieldToString(group['name'], '');
      if (id && name) {
        groupNameById.set(id, name);
      }
    }

    let addedCount = 0;
    for (const svc of services) {
      try {
        const otp = svc['otp'] as Record<string, Object> | undefined;
        if (!otp) {
          continue;
        }
        const type = this.mapOtpType(otp['tokenType']);
        const issuer = this.fieldToString(otp['issuer'], '') || this.fieldToString(otp['account'], '') || this.fieldToString(svc['name'], '');
        const auth = new Authenticator();
        auth.type = type;
        auth.secret = this.normalizeSecret(this.fieldToString(svc['secret'], ''), type);
        auth.issuer = issuer;
        auth.username = this.fieldToString(otp['issuer'], '') ? this.fieldToString(otp['account'], '') : null;
        auth.digits = this.fieldToNumber(otp['digits'], type === AuthenticatorType.SteamOtp ? 5 : 6);
        auth.period = this.fieldToNumber(otp['period'], 30);
        auth.counter = this.fieldToNumber(otp['counter'], 0);
        auth.algorithm = this.mapAlgorithm(otp['algorithm']);
        auth.icon = IconResolver.findServiceKeyByName(auth.issuer || '');

        const groupId = this.fieldToString(svc['groupId'], '');
        const groupName = groupNameById.get(groupId);
        if (groupName) {
          auth.categoryId = await this.ensureCategory(groupName);
        }

        if (auth.secret) {
          await this.authenticatorService.create(auth);
          addedCount++;
        }
      } catch (error) {
        console.error('2FAS import error:', error);
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importBitwardenVault(items: Array<Record<string, Object>>, folders: Array<Record<string, Object>>): Promise<void> {
    const folderNameById: Map<string, string> = new Map();
    for (const folder of folders) {
      const id = this.fieldToString(folder['id'], '');
      const name = this.fieldToString(folder['name'], '');
      if (id && name) {
        folderNameById.set(id, name);
      }
    }

    let addedCount = 0;
    for (const item of items) {
      try {
        if (this.fieldToNumber(item['type'], 1) !== 1) {
          continue;
        }
        const login = item['login'] as Record<string, Object> | undefined;
        const totpVal = login ? this.fieldToString(login['totp'], '') : '';
        if (!totpVal) {
          continue;
        }

        let auth: Authenticator;
        if (totpVal.startsWith('otpauth://') || totpVal.startsWith('motp://')) {
          auth = UriParser.parseStandardUri(totpVal, this.iconResolver).authenticator;
        } else {
          auth = new Authenticator();
          auth.type = totpVal.startsWith('steam://') ? AuthenticatorType.SteamOtp : AuthenticatorType.Totp;
          auth.secret = this.normalizeSecret(totpVal.startsWith('steam://') ? totpVal.substring('steam://'.length) : totpVal, auth.type);
          auth.issuer = this.fieldToString(item['name'], '');
          auth.username = login ? this.fieldToString(login['username'], '') : null;
          auth.digits = auth.type === AuthenticatorType.SteamOtp ? 5 : 6;
          auth.period = 30;
          auth.algorithm = HashAlgorithm.Sha1;
          auth.icon = IconResolver.findServiceKeyByName(auth.issuer || '');
        }

        const folderName = folderNameById.get(this.fieldToString(item['folderId'], ''));
        if (folderName) {
          auth.categoryId = await this.ensureCategory(folderName);
        }

        await this.authenticatorService.create(auth);
        addedCount++;
      } catch (error) {
        console.error('Bitwarden import error:', error);
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importLastPassBackup(accounts: Array<Record<string, Object>>, folders: Array<Record<string, Object>>): Promise<void> {
    const folderNameById: Map<number, string> = new Map();
    for (const folder of folders) {
      const id = this.fieldToNumber(folder['id'], -1);
      const name = this.fieldToString(folder['name'], '');
      if (id >= 0 && name) {
        folderNameById.set(id, name);
      }
    }

    let addedCount = 0;
    for (const account of accounts) {
      try {
        const auth = new Authenticator();
        auth.type = AuthenticatorType.Totp;
        auth.issuer = this.fieldToString(account['issuerName'], '') || this.fieldToString(account['userName'], '');
        auth.username = this.fieldToString(account['issuerName'], '') ? this.fieldToString(account['userName'], '') : null;
        auth.secret = this.normalizeSecret(this.fieldToString(account['secret'], ''), AuthenticatorType.Totp);
        auth.period = this.fieldToNumber(account['timeStep'], 30);
        auth.digits = this.fieldToNumber(account['digits'], 6);
        auth.algorithm = this.mapAlgorithm(account['algorithm']);
        auth.icon = IconResolver.findServiceKeyByName(auth.issuer || '');

        const folderData = account['folderData'] as Record<string, Object> | undefined;
        const folderId = folderData ? this.fieldToNumber(folderData['folderId'], -1) : -1;
        const folderName = folderNameById.get(folderId);
        if (folderName) {
          auth.categoryId = await this.ensureCategory(folderName);
        }

        if (auth.secret) {
          await this.authenticatorService.create(auth);
          addedCount++;
        }
      } catch (error) {
        console.error('LastPass import error:', error);
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importEnteAuthBackup(parsed: Record<string, Object>): Promise<void> {
    const items = Array.isArray(parsed['items']) ? parsed['items'] as Array<Record<string, Object>> :
      (Array.isArray(parsed['data']) ? parsed['data'] as Array<Record<string, Object>> : []);
    if (items.length > 0) {
      await this.importEnteAuthItems(items);
      return;
    }
    await this.importUriText(JSON.stringify(parsed));
  }

  private async importAegisEntries(entries: Array<Record<string, Object>>): Promise<void> {
    let addedCount = 0;
    for (const entry of entries) {
      try {
        const type = this.mapAegisType(this.fieldToString(entry['type'], 'totp'));
        const info = entry['info'] as Record<string, Object> | undefined;
        if (!info) {
          continue;
        }

        const auth = new Authenticator();
        auth.type = type;
        auth.secret = this.normalizeSecret(this.fieldToString(info['secret'], ''), type);
        auth.digits = this.fieldToNumber(info['digits'], type === AuthenticatorType.SteamOtp ? 5 : 6);
        auth.period = this.fieldToNumber(info['period'], 30);
        auth.counter = this.fieldToNumber(info['counter'], 0);
        auth.algorithm = this.mapAlgorithm(info['algo']);
        auth.pin = this.fieldToString(info['pin'], '') || null;

        const issuerRaw = this.fieldToString(entry['issuer'], '');
        const nameRaw = this.fieldToString(entry['name'], '');
        auth.issuer = issuerRaw || nameRaw;
        auth.username = issuerRaw ? nameRaw : null;

        const iconField = entry['icon'];
        if (typeof iconField === 'string' && iconField.length > 0) {
          try {
            const helper = new util.Base64Helper();
            const bytes = helper.decodeSync(iconField);
            auth.icon = await CustomIconService.getInstance().createFromBytes(bytes);
          } catch (iconErr) {
            console.error('Aegis 自定义图标导入失败:', iconErr);
            auth.icon = IconResolver.findServiceKeyByName(auth.issuer || '');
          }
        } else {
          auth.icon = IconResolver.findServiceKeyByName(auth.issuer || '');
        }

        const group = this.fieldToString(entry['group'], '');
        if (group) {
          auth.categoryId = await this.ensureCategory(group);
        }

        if (auth.secret) {
          await this.authenticatorService.create(auth);
          addedCount++;
        }
      } catch (err) {
        console.error('Aegis import error:', err);
      }
    }
    await this.showImportResult(addedCount);
  }

  private mapAegisType(value: string): AuthenticatorType {
    const text = value.toLowerCase();
    if (text === 'hotp') return AuthenticatorType.Hotp;
    if (text === 'steam') return AuthenticatorType.SteamOtp;
    if (text === 'motp') return AuthenticatorType.MobileOtp;
    if (text === 'yandex') return AuthenticatorType.YandexOtp;
    return AuthenticatorType.Totp;
  }

  private async importBitwardenItems(items: Array<Record<string, Object>>): Promise<void> {
    let addedCount = 0;
    for (const item of items) {
      try {
        const login = item['login'] as Record<string, Object> | undefined;
        if (login && login['totp']) {
          const auth = new Authenticator();
          auth.issuer = String(item['name'] || '');
          auth.username = String(login['username'] || '');
          const totpVal = String(login['totp']);
          if (totpVal.startsWith('otpauth://')) {
            try {
              const parsed = UriParser.parseStandardUri(totpVal, this.iconResolver);
              await this.authenticatorService.create(parsed.authenticator);
              addedCount++;
              continue;
            } catch (_e) {
              // fallback
            }
          }
          auth.secret = totpVal;
          auth.type = AuthenticatorType.Totp;
          auth.digits = 6;
          auth.period = 30;
          if (auth.issuer) {
            auth.icon = IconResolver.findServiceKeyByName(auth.issuer);
          }
          if (auth.secret) {
            await this.authenticatorService.create(auth);
            addedCount++;
          }
        }
      } catch (err) {
        console.error('Bitwarden import error:', err);
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importEnteAuthItems(items: Array<Record<string, Object>>): Promise<void> {
    let addedCount = 0;
    for (const item of items) {
      try {
        const rawData = String(item['rawData'] || item['uri'] || '');
        if (rawData.startsWith('otpauth://')) {
          try {
            const parsed = UriParser.parseStandardUri(rawData, this.iconResolver);
            await this.authenticatorService.create(parsed.authenticator);
            addedCount++;
          } catch (_e) {
            console.error('Failed to parse Ente Auth URI:', _e);
          }
        }
      } catch (err) {
        console.error('Ente Auth import error:', err);
      }
    }
    await this.showImportResult(addedCount);
  }

  private async importUriList(content: string): Promise<void> {
    const lines = content.split('\n');
    let addedCount = 0;
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('otpauth://') || trimmed.startsWith('motp://')) {
        try {
          const parsed = UriParser.parseStandardUri(trimmed, this.iconResolver);
          await this.authenticatorService.create(parsed.authenticator);
          addedCount++;
        } catch (err) {
          console.error('URI parse error:', err);
        }
      }
    }
    if (addedCount > 0) {
      await this.showImportResult(addedCount);
    } else {
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '未找到可导入的认证器数据', duration: 1500 });
    }
  }

  private async importUriListFromArray(uris: string[]): Promise<void> {
    let addedCount = 0;
    for (const uri of uris) {
      const trimmed = uri.trim();
      if (!trimmed.startsWith('otpauth://') && !trimmed.startsWith('motp://')) {
        continue;
      }
      try {
        const parsed = UriParser.parseStandardUri(trimmed, this.iconResolver);
        await this.authenticatorService.create(parsed.authenticator);
        addedCount++;
      } catch (err) {
        console.error('KeePass URI parse error:', err);
      }
    }
    if (addedCount > 0) {
      await this.showImportResult(addedCount);
    } else {
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '未找到可导入的认证器数据', duration: 1500 });
    }
  }

  private async importUriText(content: string): Promise<void> {
    const uris = this.extractOtpUris(content);
    let addedCount = 0;
    for (const uri of uris) {
      try {
        if (uri.startsWith('otpauth-migration://')) {
          const auths = UriParser.parseOtpAuthMigrationUri(uri, this.iconResolver);
          for (const auth of auths) {
            await this.authenticatorService.create(auth);
            addedCount++;
          }
          continue;
        }
        const parsed = UriParser.parseStandardUri(uri, this.iconResolver);
        await this.authenticatorService.create(parsed.authenticator);
        addedCount++;
      } catch (error) {
        console.error('URI text import error:', error);
      }
    }

    if (addedCount > 0) {
      await this.showImportResult(addedCount);
    } else {
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({ message: '未找到可导入的认证器数据', duration: 1500 });
    }
  }

  private extractOtpUris(content: string): string[] {
    const normalized = content
      .replace(/&amp;/g, '&')
      .replace(/\\\//g, '/')
      .replace(/\\u003d/g, '=')
      .replace(/\\u0026/g, '&');
    const matches = normalized.match(/(?:otpauth-migration|otpauth|motp):\/\/[^\s"'<>),]+/g);
    if (!matches) {
      return [];
    }
    const unique: string[] = [];
    for (const match of matches) {
      const uri = match.trim();
      if (!unique.includes(uri)) {
        unique.push(uri);
      }
    }
    return unique;
  }

  private async showImportResult(count: number): Promise<void> {
    const prompt = this.getUIContext().getPromptAction();
    if (count > 0) {
      prompt.showToast({ message: `导入成功，添加了 ${count} 个认证器`, duration: 2000 });
      // 延迟返回主页
      setTimeout((): void => {
        this.getUIContext().getRouter().back();
      }, 1200);
    } else {
      prompt.showToast({ message: '未找到可导入的认证器', duration: 1500 });
    }
  }

  private onSourceTap(source: ImportSourceItem): void {
    if (source.isGuideOnly) {
      const prompt = this.getUIContext().getPromptAction();
      prompt.showToast({
        message: source.hint,
        duration: 3000
      });
    } else {
      this.pickAndImportFile(source);
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部栏（含状态栏安全区）
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
            Text('从其他应用导入')
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

        // 提示信息
        Row() {
          Text('选择你之前使用的认证器应用，然后按照提示导入数据。')
            .fontSize(13)
            .fontColor(this.getColors().textSecondary)
            .margin({ left: 16, right: 16, top: 8, bottom: 8 })
        }
        .width('100%')

        // 应用列表
        List({ space: 0 }) {
          ForEach(this.sources, (source: ImportSourceItem) => {
            ListItem() {
              Row() {
                Image($r(`app.media.${source.icon}`))
                  .width(40).height(40)
                  .borderRadius(8)
                  .margin({ left: 16 })

                Column({ space: 2 }) {
                  Text(source.name)
                    .fontSize(16)
                    .fontWeight(500)
                    .fontColor(this.getColors().text)
                  Row() {
                    if (source.isGuideOnly) {
                      Text('查看指南')
                        .fontSize(12)
                        .fontColor(this.getColors().primary)
                    } else {
                      Text('选择文件导入')
                        .fontSize(12)
                        .fontColor(this.getColors().textSecondary)
                    }
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })
                .flexGrow(1)

                Image($r('app.media.baseline_chevron_right_24'))
                  .width(20).height(20)
                  .fillColor(this.getColors().textSecondary)
                  .margin({ right: 16 })
              }
              .width('100%')
              .height(64)
              .alignItems(VerticalAlign.Center)
              .backgroundColor(this.getColors().surface)
              .borderRadius(12)
              .onClick(() => {
                this.onSourceTap(source);
              })
            }
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          }, (source: ImportSourceItem): string => source.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getColors().background)

      ImportPasswordDialog({
        visible: this.showImportPasswordDialog,
        colors: { background: this.getColors().background, surface: this.getColors().surface, onSurface: this.getColors().text, border: this.getColors().divider },
        title: '请输入导入密码',
        placeholder: '密码',
        confirmText: '导入',
        password: this.importPassword,
        onChange: (value: string): void => { this.importPassword = value; },
        onCancel: (): void => { this.closeImportPasswordDialog(); },
        onConfirm: (): void => { this.confirmImportPassword(); }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getColors().background)
  }
}
