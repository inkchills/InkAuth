// ThirdPartyCrypto.ets — decrypt helpers for third-party encrypted backups

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { hashRaw } from '@ohos-rs/argon2';
import { scrypt, hexToBytes } from './ScryptUtil';
import { xchacha20Poly1305Pull } from './XChaCha20Util';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'ThirdPartyCrypto';

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

export class ThirdPartyCrypto {
  public static async decryptAndOtp(data: Uint8Array, password: string): Promise<string> {
    const iterationsLength = 4;
    const saltLength = 12;
    const ivLength = 12;
    const tagLength = 16;

    if (data.length <= iterationsLength + saltLength + ivLength + tagLength) {
      throw new Error('andOTP 加密文件太短');
    }

    const iterations = ThirdPartyCrypto.readUint32BE(data, 0);
    if (iterations < 1 || iterations > 5000000) {
      throw new Error('andOTP 迭代次数无效');
    }

    const salt = data.slice(iterationsLength, iterationsLength + saltLength);
    const iv = data.slice(iterationsLength + saltLength, iterationsLength + saltLength + ivLength);
    const cipherPlusTag = data.slice(iterationsLength + saltLength + ivLength);
    const authTag = cipherPlusTag.slice(cipherPlusTag.length - tagLength);
    const ciphertext = cipherPlusTag.slice(0, cipherPlusTag.length - tagLength);

    const key = await ThirdPartyCrypto.pbkdf2(password, salt, iterations, 32, 'SHA1');
    return await ThirdPartyCrypto.aesGcmDecryptToString(key, iv, ciphertext, authTag);
  }

  public static async decryptTwoFas(servicesEncrypted: string, password: string): Promise<string> {
    const parts = servicesEncrypted.split(':');
    if (parts.length < 3) {
      throw new Error('2FAS 加密载荷格式无效');
    }

    const helper = new util.Base64Helper();
    const encryptedData = helper.decodeSync(parts[0]);
    const salt = helper.decodeSync(parts[1]);
    const iv = helper.decodeSync(parts[2]);
    const tagLength = 16;

    if (encryptedData.length <= tagLength) {
      throw new Error('2FAS 密文太短');
    }

    const authTag = encryptedData.slice(encryptedData.length - tagLength);
    const ciphertext = encryptedData.slice(0, encryptedData.length - tagLength);
    const key = await ThirdPartyCrypto.pbkdf2(password, salt, 10000, 32, 'SHA256');
    return await ThirdPartyCrypto.aesGcmDecryptToString(key, iv, ciphertext, authTag);
  }

  public static async decryptAegis(backupJson: string, password: string): Promise<string> {
    const backup = JSON.parse(backupJson) as Record<string, Object>;
    if (Number(backup['version'] ?? 1) !== 1) {
      throw new Error('不支持的 Aegis 备份版本');
    }

    const header = backup['header'] as Record<string, Object> | undefined;
    if (!header) {
      throw new Error('Aegis 备份缺少 header');
    }
    const slots = header['slots'] as Array<Record<string, Object>> | undefined;
    const params = header['params'] as Record<string, Object> | undefined;
    if (!slots || !params) {
      throw new Error('Aegis 加密备份缺少 slots/params');
    }

    const passwordBytes = ThirdPartyCrypto.utf8Encode(password);
    let masterKey: Uint8Array | null = null;
    for (const slot of slots) {
      if (Number(slot['type']) !== 1) {
        continue;
      }
      try {
        masterKey = await ThirdPartyCrypto.decryptAegisSlot(slot, passwordBytes);
        break;
      } catch (_err) {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'Aegis slot decrypt failed, try next');
      }
    }
    if (!masterKey) {
      throw new Error('Aegis 主密钥解密失败，密码可能不正确');
    }

    const helper = new util.Base64Helper();
    const dbField = backup['db'];
    if (typeof dbField !== 'string') {
      throw new Error('Aegis 加密备份 db 字段无效');
    }
    const databaseBytes = helper.decodeSync(dbField);
    const iv = hexToBytes(String(params['nonce'] || ''));
    const tag = hexToBytes(String(params['tag'] || ''));
    return await ThirdPartyCrypto.aesGcmDecryptToString(masterKey, iv, databaseBytes, tag);
  }

  private static async decryptAegisSlot(slot: Record<string, Object>, passwordBytes: Uint8Array): Promise<Uint8Array> {
    const salt = hexToBytes(String(slot['salt'] || ''));
    const n = Number(slot['n'] || 32768);
    const r = Number(slot['r'] || 8);
    const p = Number(slot['p'] || 1);
    const derived = await scrypt(passwordBytes, salt, n, r, p, 32);

    const keyParams = slot['key_params'] as Record<string, Object> | undefined;
    if (!keyParams) {
      throw new Error('Aegis slot 缺少 key_params');
    }
    const iv = hexToBytes(String(keyParams['nonce'] || ''));
    const tag = hexToBytes(String(keyParams['tag'] || ''));
    const keyCipher = hexToBytes(String(slot['key'] || ''));
    return await ThirdPartyCrypto.aesGcmDecryptToBytes(derived, iv, keyCipher, tag);
  }

  public static async decryptBitwarden(backupJson: string, password: string): Promise<string> {
    const encryption = JSON.parse(backupJson) as Record<string, Object>;
    if (encryption['encrypted'] !== true) {
      throw new Error('不是 Bitwarden 加密导出');
    }
    if (encryption['passwordProtected'] === false) {
      throw new Error('不支持账号受限的 Bitwarden 备份');
    }

    const key = await ThirdPartyCrypto.deriveBitwardenKey(encryption, password);
    const encKey = await ThirdPartyCrypto.hkdfExpandOnly(key, 'enc', 32);
    const macKey = await ThirdPartyCrypto.hkdfExpandOnly(key, 'mac', 32);

    const dataField = String(encryption['data'] || '');
    const dot = dataField.indexOf('.');
    if (dot < 0) {
      throw new Error('Bitwarden 加密数据格式无效');
    }
    const encType = dataField.substring(0, dot);
    if (encType !== '2') {
      throw new Error(`不支持的 Bitwarden 加密类型: ${encType}`);
    }
    const parts = dataField.substring(dot + 1).split('|');
    if (parts.length < 3) {
      throw new Error('Bitwarden 加密数据缺少分段');
    }

    const helper = new util.Base64Helper();
    const iv = helper.decodeSync(parts[0]);
    const payload = helper.decodeSync(parts[1]);
    const mac = helper.decodeSync(parts[2]);

    const material = new Uint8Array(iv.length + payload.length);
    material.set(iv, 0);
    material.set(payload, iv.length);
    const computedMac = await ThirdPartyCrypto.hmacSha256(macKey, material);
    if (!ThirdPartyCrypto.constantTimeEqual(computedMac, mac)) {
      throw new Error('Bitwarden 密码错误（HMAC 校验失败）');
    }

    const decrypted = await ThirdPartyCrypto.aesCbcDecrypt(encKey, iv, payload);
    return ThirdPartyCrypto.utf8Decode(decrypted);
  }

  private static async deriveBitwardenKey(encryption: Record<string, Object>, password: string): Promise<Uint8Array> {
    const saltString = String(encryption['salt'] || '');
    const saltBytes = ThirdPartyCrypto.utf8Encode(saltString);
    const kdfType = Number(encryption['kdfType'] ?? 0);
    const iterations = Number(encryption['kdfIterations'] ?? 600000);

    if (kdfType === 0) {
      return await ThirdPartyCrypto.pbkdf2(password, saltBytes, iterations, 32, 'SHA256');
    }
    if (kdfType === 1) {
      const memory = Number(encryption['kdfMemory']);
      const parallelism = Number(encryption['kdfParallelism']);
      if (!memory || !parallelism) {
        throw new Error('Bitwarden Argon2 缺少 memory/parallelism');
      }
      const saltHash = await ThirdPartyCrypto.sha256(saltBytes);
      return await ThirdPartyCrypto.argon2id(password, saltHash, iterations, memory * 1024, parallelism, 32);
    }
    throw new Error(`不支持的 Bitwarden KDF: ${kdfType}`);
  }

  public static async decryptEnte(backupJson: string, password: string): Promise<string> {
    const backup = JSON.parse(backupJson) as Record<string, Object>;
    if (Number(backup['version']) !== 1) {
      throw new Error('不支持的 Ente Auth 备份版本');
    }
    const kdfParams = backup['kdfParams'] as Record<string, Object> | undefined;
    if (!kdfParams) {
      throw new Error('Ente Auth 缺少 kdfParams');
    }

    const helper = new util.Base64Helper();
    const salt = helper.decodeSync(String(kdfParams['salt'] || ''));
    const opsLimit = Number(kdfParams['opsLimit'] || 4);
    const memLimit = Number(kdfParams['memLimit'] || 1073741824);
    const memoryKiB = Math.floor(memLimit / 1024);

    const key = await ThirdPartyCrypto.argon2id(password, salt, opsLimit, memoryKiB, 1, 32);
    const encryptedData = helper.decodeSync(String(backup['encryptedData'] || ''));
    const header = helper.decodeSync(String(backup['encryptionNonce'] || ''));
    const plain = xchacha20Poly1305Pull(key, header, encryptedData);
    return ThirdPartyCrypto.utf8Decode(plain);
  }

  private static async pbkdf2(
    password: string,
    salt: Uint8Array,
    iterations: number,
    keySize: number,
    hash: string
  ): Promise<Uint8Array> {
    const alg = hash === 'SHA256' ? 'PBKDF2|SHA256' : 'PBKDF2|SHA1';
    const kdf = cryptoFramework.createKdf(alg);
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2',
      password: password,
      salt: salt,
      iterations: iterations,
      keySize: keySize
    };
    const derived = await kdf.generateSecret(spec);
    return derived.data;
  }

  private static async argon2id(
    password: string,
    salt: Uint8Array,
    timeCost: number,
    memoryCostKiB: number,
    parallelism: number,
    outputLen: number
  ): Promise<Uint8Array> {
    const saltAb = salt.buffer.slice(salt.byteOffset, salt.byteOffset + salt.byteLength) as ArrayBuffer;
    const options: Argon2RawOptions = {
      salt: saltAb,
      algorithm: 2,
      version: 1,
      timeCost: timeCost,
      memoryCost: memoryCostKiB,
      parallelism: parallelism,
      outputLen: outputLen
    };
    const fn = hashRaw as Argon2HashRawFn | undefined;
    if (!fn) {
      throw new Error('Argon2 不可用');
    }
    return new Uint8Array(await fn(password, options));
  }

  private static async hkdfExpandOnly(prk: Uint8Array, info: string, length: number): Promise<Uint8Array> {
    const infoBytes = ThirdPartyCrypto.utf8Encode(info);
    const hashLen = 32;
    const n = Math.ceil(length / hashLen);
    const okm = new Uint8Array(n * hashLen);
    let previous = new Uint8Array(0);
    let offset = 0;
    for (let i = 1; i <= n; i++) {
      const input = new Uint8Array(previous.length + infoBytes.length + 1);
      input.set(previous, 0);
      input.set(infoBytes, previous.length);
      input[input.length - 1] = i;
      previous = await ThirdPartyCrypto.hmacSha256(prk, input);
      okm.set(previous, offset);
      offset += hashLen;
    }
    return okm.slice(0, length);
  }

  private static async hmacSha256(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
    const mac = cryptoFramework.createMac('HMACSHA256');
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
    const symKey = await symKeyGenerator.convertKey({ data: key });
    await mac.init(symKey);
    await mac.update({ data: data });
    const result = await mac.doFinal();
    return result.data;
  }

  private static async sha256(data: Uint8Array): Promise<Uint8Array> {
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: data });
    const digest = await md.digest();
    return digest.data;
  }

  private static async aesGcmDecryptToString(
    key: Uint8Array,
    iv: Uint8Array,
    ciphertext: Uint8Array,
    authTag: Uint8Array
  ): Promise<string> {
    const bytes = await ThirdPartyCrypto.aesGcmDecryptToBytes(key, iv, ciphertext, authTag);
    return ThirdPartyCrypto.utf8Decode(bytes);
  }

  private static async aesGcmDecryptToBytes(
    key: Uint8Array,
    iv: Uint8Array,
    ciphertext: Uint8Array,
    authTag: Uint8Array
  ): Promise<Uint8Array> {
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
    const symKey = await symKeyGenerator.convertKey({ data: key });
    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: iv },
      authTag: { data: authTag },
      aad: { data: new Uint8Array() }
    };
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParams);
    const decrypted = await cipher.doFinal({ data: ciphertext });
    if (!decrypted || !decrypted.data) {
      throw new Error('解密结果为空');
    }
    return decrypted.data;
  }

  private static async aesCbcDecrypt(key: Uint8Array, iv: Uint8Array, ciphertext: Uint8Array): Promise<Uint8Array> {
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
    const symKey = await symKeyGenerator.convertKey({ data: key });
    const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
    const ivParam: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: { data: iv }
    };
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, ivParam);
    const decrypted = await cipher.doFinal({ data: ciphertext });
    if (!decrypted || !decrypted.data) {
      throw new Error('AES-CBC 解密结果为空');
    }
    return decrypted.data;
  }

  private static constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
    if (a.length !== b.length) {
      return false;
    }
    let diff = 0;
    for (let i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff === 0;
  }

  private static readUint32BE(data: Uint8Array, offset: number): number {
    return ((data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3]) >>> 0;
  }

  public static utf8Encode(value: string): Uint8Array {
    const buffer = new ArrayBuffer(value.length * 3);
    const view = new Uint8Array(buffer);
    let offset = 0;
    for (let i = 0; i < value.length; i++) {
      let code = value.charCodeAt(i);
      if (code < 0x80) {
        view[offset++] = code;
      } else if (code < 0x800) {
        view[offset++] = 0xC0 | (code >> 6);
        view[offset++] = 0x80 | (code & 0x3F);
      } else {
        view[offset++] = 0xE0 | (code >> 12);
        view[offset++] = 0x80 | ((code >> 6) & 0x3F);
        view[offset++] = 0x80 | (code & 0x3F);
      }
    }
    return view.slice(0, offset);
  }

  public static utf8Decode(data: Uint8Array): string {
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
}
