// BackupService.ets

import { IBackupService } from '../IBackupService';
import { AuthenticatorService } from './AuthenticatorService';
import { AuthenticatorType } from '../../AuthenticatorType';
import { HashAlgorithm } from '../../generator/HashAlgorithm';
import { CategoryService } from './CategoryService';
import { Category } from '../../entity/Category';
import { CustomIconService } from './CustomIconService';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { hashRaw, hashRawSync } from '@ohos-rs/argon2';
import { createQrSvgDataUri } from '../../util/QrCodeSvg';


const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'BackupService';
const STRONG_BACKUP_HEADER: string = 'AUTHENTICATORPRO';

interface InkAuthAuthenticatorBackup {
  Type: number;
  Icon: string | null;
  Issuer: string | null;
  Username: string | null;
  Secret: string;
  Pin: string | null;
  Algorithm: number;
  Digits: number;
  Period: number;
  Counter: number;
  CopyCount: number;
  Ranking: number;
}

interface InkAuthCategoryBackup {
  Id: string;
  Name: string;
  Ranking: number;
}

interface InkAuthAuthenticatorCategoryBackup {
  CategoryId: string;
  AuthenticatorSecret: string;
  Ranking: number;
}

interface InkAuthCustomIconBackup {
  Id: string;
  Data: string;
}

interface InkAuthBackupData {
  Authenticators: Array<InkAuthAuthenticatorBackup>;
  Categories: Array<InkAuthCategoryBackup>;
  AuthenticatorCategories: Array<InkAuthAuthenticatorCategoryBackup>;
  CustomIcons: Array<InkAuthCustomIconBackup>;
}

interface Argon2RawOptions {
  salt: ArrayBuffer;
  algorithm: number;
  version: number;
  timeCost: number;
  memoryCost: number;
  parallelism: number;
  outputLen: number;
}

type Argon2HashRawFn = (password: string | ArrayBuffer, options: Argon2RawOptions) => Promise<ArrayBuffer>;
type Argon2HashRawSyncFn = (password: string | ArrayBuffer, options: Argon2RawOptions) => ArrayBuffer;

export class BackupService implements IBackupService {
  private authenticatorService: AuthenticatorService = AuthenticatorService.getInstance();
  private categoryService: CategoryService = CategoryService.getInstance();
  private customIconService: CustomIconService = CustomIconService.getInstance();

  public async createBackupAsync(): Promise<Uint8Array> {
    const authenticators = await this.authenticatorService.getAll();
    const categories = await this.categoryService.getAll();
    const customIcons = await this.customIconService.getAll();
    const backupItems: InkAuthAuthenticatorBackup[] = [];
    const categoryItems: InkAuthCategoryBackup[] = [];
    const bindingItems: InkAuthAuthenticatorCategoryBackup[] = [];
    const customIconItems: InkAuthCustomIconBackup[] = [];

    for (const auth of authenticators) {
      const backupItem: InkAuthAuthenticatorBackup = {
        Type: this.toAndroidAuthenticatorType(auth.type),
        Icon: auth.icon,
        Issuer: auth.issuer,
        Username: auth.username,
        Secret: auth.secret || '',
        Pin: auth.pin,
        Algorithm: auth.algorithm as number,
        Digits: auth.digits || 6,
        Period: auth.period || 30,
        Counter: auth.counter || 0,
        CopyCount: auth.copyCount || 0,
        Ranking: auth.ranking || 0
      };
      backupItems.push(backupItem);

      if (auth.categoryId) {
        const bindingItem: InkAuthAuthenticatorCategoryBackup = {
          CategoryId: auth.categoryId,
          AuthenticatorSecret: auth.secret || '',
          Ranking: auth.ranking || 0
        };
        bindingItems.push(bindingItem);
      }
    }

    for (const category of categories) {
      const categoryItem: InkAuthCategoryBackup = {
        Id: category.id,
        Name: category.name,
        Ranking: category.ranking
      };
      categoryItems.push(categoryItem);
    }

    for (const icon of customIcons) {
      customIconItems.push({ Id: icon.id, Data: icon.data });
    }

    const backupData: InkAuthBackupData = {
      Authenticators: backupItems,
      Categories: categoryItems,
      AuthenticatorCategories: bindingItems,
      CustomIcons: customIconItems
    };

    const jsonString = JSON.stringify(backupData);
    return this.stringToUint8Array(jsonString);
  }

  public async createEncryptedBackupAsync(password: string): Promise<Uint8Array> {
    if (!password) {
      throw new Error('备份密码不能为空');
    }

    const plainBackup = await this.createBackupAsync();
    return this.encryptStrong(plainBackup, password);
  }

  public async createHtmlBackupAsync(): Promise<string> {
    const authenticators = await this.authenticatorService.getAll();

    let htmlContent = `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Authenticator Backup</title>
    <style>
      body { font-family: sans-serif; margin: 24px; }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #ccc; padding: 8px; vertical-align: top; }
      th { background: #f5f5f5; text-align: left; }
      img.qr { width: 128px; height: 128px; }
      code { word-break: break-all; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Authenticator Backup</h1>
    <p>Generated on: ${new Date().toLocaleString()}</p>
    <table>
      <thead>
        <tr><th>Issuer</th><th>Username</th><th>URI</th><th>QR</th></tr>
      </thead>
      <tbody>`;

    for (const auth of authenticators) {
      let uri = '';
      try {
        uri = auth.getUri();
      } catch (_e) {
        continue;
      }
      const issuer = this.escapeHtml(auth.issuer || '');
      const username = this.escapeHtml(auth.username || '');
      const otpUri = this.escapeHtml(uri);
      let qrSrc = '';
      try {
        qrSrc = createQrSvgDataUri(uri);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'QR SVG failed: %{public}s', String(err));
      }
      const qrCell = qrSrc
        ? `<img class="qr" alt="QR" src="${qrSrc}">`
        : '';
      htmlContent += `\n        <tr><td>${issuer}</td><td>${username}</td><td><code>${otpUri}</code></td><td>${qrCell}</td></tr>`;
    }

    htmlContent += `\n      </tbody>\n    </table>\n</body>\n</html>`;
    return htmlContent;
  }

  public async createUriListBackupAsync(): Promise<string> {
    const authenticators = await this.authenticatorService.getAll();
    let uriList = '';

    for (const auth of authenticators) {
      uriList += auth.getUri() + '\n';
    }

    return uriList;
  }

  private toAndroidAuthenticatorType(type: AuthenticatorType): number {
    switch (type) {
      case AuthenticatorType.Hotp:
        return 1;
      case AuthenticatorType.Totp:
        return 2;
      case AuthenticatorType.MobileOtp:
        return 3;
      case AuthenticatorType.SteamOtp:
        return 4;
      case AuthenticatorType.YandexOtp:
        return 5;
      default:
        return 2;
    }
  }

  private stringToUint8Array(value: string): Uint8Array {
    const bytes: number[] = [];
    for (let i = 0; i < value.length; i++) {
      let codePoint = value.charCodeAt(i);
      if (codePoint >= 0xD800 && codePoint <= 0xDBFF && i + 1 < value.length) {
        const next = value.charCodeAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          codePoint = 0x10000 + ((codePoint - 0xD800) << 10) + (next - 0xDC00);
          i++;
        }
      }

      if (codePoint < 0x80) {
        bytes.push(codePoint);
      } else if (codePoint < 0x800) {
        bytes.push(0xC0 | (codePoint >> 6));
        bytes.push(0x80 | (codePoint & 0x3F));
      } else if (codePoint < 0x10000) {
        bytes.push(0xE0 | (codePoint >> 12));
        bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
        bytes.push(0x80 | (codePoint & 0x3F));
      } else {
        bytes.push(0xF0 | (codePoint >> 18));
        bytes.push(0x80 | ((codePoint >> 12) & 0x3F));
        bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
        bytes.push(0x80 | (codePoint & 0x3F));
      }
    }
    return new Uint8Array(bytes);
  }

  private concatBytes(parts: Uint8Array[]): Uint8Array {
    let totalLength = 0;
    for (const part of parts) {
      totalLength += part.length;
    }

    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (const part of parts) {
      result.set(part, offset);
      offset += part.length;
    }
    return result;
  }

  private async secureRandomBytes(length: number): Promise<Uint8Array> {
    const random = cryptoFramework.createRandom();
    const blob = await random.generateRandom(length);
    return blob.data;
  }

  private async deriveStrongKey(password: string, salt: Uint8Array): Promise<Uint8Array> {
    const saltArrayBuffer = salt.buffer.slice(salt.byteOffset, salt.byteOffset + salt.byteLength) as ArrayBuffer;
    const options: Argon2RawOptions = {
      salt: saltArrayBuffer,
      algorithm: 2,
      version: 1,
      timeCost: 3,
      memoryCost: 65536,
      parallelism: 4,
      outputLen: 32
    };

    const hashRawFn = hashRaw as Argon2HashRawFn | undefined;
    if (hashRawFn) {
      return new Uint8Array(await hashRawFn(password, options));
    }

    const hashRawSyncFn = hashRawSync as Argon2HashRawSyncFn | undefined;
    if (hashRawSyncFn) {
      return new Uint8Array(hashRawSyncFn(password, options));
    }

    throw new Error('argon2 raw hash function not available');
  }

  private escapeHtml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  /**
   * 解密备份数据
   * @param data 加密的原始字节
   * @param password 密码
   * @param encryptionType 加密类型 'strong' | 'legacy'
   * @returns 解密后的文本内容
   */
  public async decryptBackup(data: Uint8Array, password: string, encryptionType: string): Promise<string> {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'decryptBackup called, type=%{public}s, dataLen=%{public}d', encryptionType, data.length);

    if (encryptionType === 'legacy') {
      return this.decryptLegacy(data, password);
    } else if (encryptionType === 'strong') {
      return this.decryptStrong(data, password);
    } else {
      throw new Error('不支持的加密类型: ' + encryptionType);
    }
  }

  /**
   * Legacy 解密: PBKDF2-SHA1 + AES-256-CBC (PKCS7)
   * 格式: Header("AuthenticatorPro", 16B) + Salt(20B) + IV(16B) + Ciphertext
   */
  private async decryptLegacy(data: Uint8Array, password: string): Promise<string> {
    const headerLength = 16;
    const saltLength = 20;
    const ivLength = 16;

    if (data.length <= headerLength + saltLength + ivLength) {
      throw new Error('Legacy 加密文件太短');
    }

    const salt = data.slice(headerLength, headerLength + saltLength);
    const iv = data.slice(headerLength + saltLength, headerLength + saltLength + ivLength);
    const encrypted = data.slice(headerLength + saltLength + ivLength);

    hilog.info(LOG_DOMAIN, LOG_TAG, 'Legacy: salt=%{public}d, iv=%{public}d, encrypted=%{public}d', salt.length, iv.length, encrypted.length);

    // PBKDF2-SHA1 密钥派生
    const kdf = cryptoFramework.createKdf('PBKDF2|SHA1');
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2',
      password: password,
      salt: salt,
      iterations: 64000,
      keySize: 32
    };
    const derivedKey = await kdf.generateSecret(spec);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Legacy: key derived, keyLen=%{public}d', derivedKey.data.length);

    // 将派生密钥转为 SymKey
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
    const keyBlob: cryptoFramework.DataBlob = { data: derivedKey.data };
    const symKey = await symKeyGenerator.convertKey(keyBlob);

    // AES-256-CBC 解密 (PKCS7 padding)
    const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
    const ivParam: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: { data: iv }
    };
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, ivParam);
    const decrypted = await cipher.doFinal({ data: encrypted });

    if (!decrypted || !decrypted.data) {
      throw new Error('Legacy 解密结果为空');
    }

    const result = this.uint8ArrayToString(decrypted.data);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Legacy: decrypted OK, len=%{public}d', result.length);
    return result;
  }

  /**
   * Strong 解密: Argon2id + AES-256-GCM
   * 格式: Header("AUTHENTICATORPRO", 16B) + Salt(16B) + IV(12B) + Ciphertext+Tag
   * GCM Tag 在密文末尾 16B
   *
   * 使用 @ohos-rs/argon2 原生库进行 Argon2id 密钥派生
   */
  private async decryptStrong(data: Uint8Array, password: string): Promise<string> {
    const headerLength = 16;
    const saltLength = 16;
    const ivLength = 12;
    const tagLength = 16;

    if (data.length <= headerLength + saltLength + ivLength + tagLength) {
      throw new Error('Strong 加密文件太短');
    }

    const salt = data.slice(headerLength, headerLength + saltLength);
    const iv = data.slice(headerLength + saltLength, headerLength + saltLength + ivLength);
    const cipherPlusTag = data.slice(headerLength + saltLength + ivLength);

    // GCM tag 在数据末尾
    const authTag = cipherPlusTag.slice(cipherPlusTag.length - tagLength);
    const ciphertext = cipherPlusTag.slice(0, cipherPlusTag.length - tagLength);

    hilog.info(LOG_DOMAIN, LOG_TAG, 'Strong: salt=%{public}d, iv=%{public}d, cipher=%{public}d, tag=%{public}d',
      salt.length, iv.length, ciphertext.length, authTag.length);

    // Argon2id 密钥派生 (使用 @ohos-rs/argon2 原生库)
    // 匹配 C# 参数: Argon2id, Parallelism=4, Iterations=3, MemorySize=65536KB, KeyLength=32
    const key = await this.deriveStrongKey(password, salt);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Strong: Argon2id key derived via @ohos-rs/argon2, keyLen=%{public}d', key.length);

    // 将密钥转为 SymKey
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
    const keyBlob: cryptoFramework.DataBlob = { data: key };
    const symKey = await symKeyGenerator.convertKey(keyBlob);

    // AES-256-GCM 解密
    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: iv },
      aad: { data: new Uint8Array(0) },
      authTag: { data: authTag }
    };
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParams);
    const decrypted = await cipher.doFinal({ data: ciphertext });

    if (!decrypted || !decrypted.data) {
      throw new Error('Strong 解密结果为空');
    }

    const result = this.uint8ArrayToString(decrypted.data);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Strong: decrypted OK, len=%{public}d', result.length);
    return result;
  }

  private async encryptStrong(data: Uint8Array, password: string): Promise<Uint8Array> {
    const saltLength = 16;
    const ivLength = 12;

    const salt = await this.secureRandomBytes(saltLength);
    const iv = await this.secureRandomBytes(ivLength);

    const key = await this.deriveStrongKey(password, salt);
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
    const symKey = await symKeyGenerator.convertKey({ data: key });

    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: iv },
      aad: { data: new Uint8Array(0) },
      authTag: { data: new Uint8Array(16) }
    };
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, gcmParams);
    const encrypted = await cipher.doFinal({ data: data });

    return this.concatBytes([
      this.stringToUint8Array(STRONG_BACKUP_HEADER),
      salt,
      iv,
      encrypted.data
    ]);
  }

  private uint8ArrayToString(arr: Uint8Array): string {
    // UTF-8 解码
    let result = '';
    let i = 0;
    while (i < arr.length) {
      const byte1 = arr[i];
      if (byte1 < 0x80) {
        result += String.fromCharCode(byte1);
        i++;
      } else if ((byte1 & 0xE0) === 0xC0) {
        const byte2 = arr[i + 1];
        result += String.fromCharCode(((byte1 & 0x1F) << 6) | (byte2 & 0x3F));
        i += 2;
      } else if ((byte1 & 0xF0) === 0xE0) {
        const byte2 = arr[i + 1];
        const byte3 = arr[i + 2];
        result += String.fromCharCode(((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F));
        i += 3;
      } else if ((byte1 & 0xF8) === 0xF0) {
        const byte2 = arr[i + 1];
        const byte3 = arr[i + 2];
        const byte4 = arr[i + 3];
        const codePoint = ((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F);
        // 使用代理对
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
}
