// CustomIconService.ets — persist custom icons (Android @id compatible)

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { image } from '@kit.ImageKit';
import { CustomIcon } from '../../entity/CustomIcon';
import { IconResolver } from '../../util/IconResolver';
import { util } from '@kit.ArkTS';

interface CustomIconData {
  id: string;
  data: string;
}

export class CustomIconService {
  private static instance: CustomIconService;
  private _icons: Map<string, CustomIcon> = new Map();
  private _store: preferences.Preferences | null = null;
  private _initialized: boolean = false;
  private static readonly STORE_NAME: string = 'custom_icon_store';
  private static readonly KEY_ICONS: string = 'custom_icons';

  private constructor() {}

  public static getInstance(): CustomIconService {
    if (!CustomIconService.instance) {
      CustomIconService.instance = new CustomIconService();
    }
    return CustomIconService.instance;
  }

  public async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this._initialized) {
      return;
    }
    try {
      const options: preferences.Options = { name: CustomIconService.STORE_NAME };
      this._store = preferences.getPreferencesSync(context, options);
      await this.loadFromStore();
      this.registerAllInResolver();
      this._initialized = true;
    } catch (err) {
      console.error('初始化自定义图标存储失败，回退非加密存储:', err);
      try {
        const fallback: preferences.Options = { name: CustomIconService.STORE_NAME };
        this._store = preferences.getPreferencesSync(context, fallback);
        await this.loadFromStore();
        this.registerAllInResolver();
        this._initialized = true;
      } catch (err2) {
        console.error('自定义图标存储初始化彻底失败:', err2);
      }
    }
  }

  private async loadFromStore(): Promise<void> {
    if (!this._store) {
      return;
    }
    try {
      const jsonStr = this._store.getSync(CustomIconService.KEY_ICONS, '[]') as string;
      const list: CustomIconData[] = JSON.parse(jsonStr) as CustomIconData[];
      this._icons.clear();
      for (const item of list) {
        if (item.id && item.data) {
          this._icons.set(item.id, new CustomIcon(item.id, item.data));
        }
      }
    } catch (err) {
      console.error('加载自定义图标失败:', err);
    }
  }

  private async saveToStore(): Promise<void> {
    if (!this._store) {
      return;
    }
    const list: CustomIconData[] = [];
    for (const icon of this._icons.values()) {
      list.push({ id: icon.id, data: icon.data });
    }
    this._store.putSync(CustomIconService.KEY_ICONS, JSON.stringify(list));
    await this._store.flush();
  }

  private registerAllInResolver(): void {
    for (const icon of this._icons.values()) {
      IconResolver.registerCustomIcon(CustomIcon.toIconKey(icon.id), icon.toDataUri());
    }
  }

  public async getAll(): Promise<CustomIcon[]> {
    return Array.from(this._icons.values());
  }

  public getById(id: string): CustomIcon | null {
    return this._icons.get(id) || null;
  }

  public async upsert(icon: CustomIcon): Promise<void> {
    this._icons.set(icon.id, icon);
    IconResolver.registerCustomIcon(CustomIcon.toIconKey(icon.id), icon.toDataUri());
    await this.saveToStore();
  }

  public async delete(id: string): Promise<void> {
    this._icons.delete(id);
    IconResolver.unregisterCustomIcon(CustomIcon.toIconKey(id));
    await this.saveToStore();
  }

  public async clear(): Promise<void> {
    this._icons.clear();
    IconResolver.clearCustomIcons();
    await this.saveToStore();
  }

  public async importFromBackup(items: Array<Record<string, Object>>): Promise<number> {
    let count = 0;
    for (const item of items) {
      const id = this.fieldToString(item['Id'] ?? item['id'], '');
      const dataField = item['Data'] ?? item['data'];
      let data = '';
      if (typeof dataField === 'string') {
        data = dataField;
      } else if (dataField instanceof Uint8Array) {
        data = this.bytesToBase64(dataField);
      } else if (Array.isArray(dataField)) {
        data = this.bytesToBase64(Uint8Array.from(dataField as number[]));
      }
      if (!id || !data) {
        continue;
      }
      await this.upsert(new CustomIcon(id, data));
      count++;
    }
    return count;
  }

  /**
   * Decode image from file URI, resize to square MaxSize, store as PNG base64, return icon key (@id).
   */
  public async createFromImageUri(uri: string): Promise<string> {
    const source = image.createImageSource(uri);
    const decodingOptions: image.DecodingOptions = {
      desiredSize: { width: CustomIcon.MaxSize, height: CustomIcon.MaxSize }
    };
    const pixelMap = await source.createPixelMap(decodingOptions);
    try {
      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/png', quality: 100 };
      const packed: ArrayBuffer = await packer.packing(pixelMap, packOpts);
      const bytes = new Uint8Array(packed);
      const base64 = this.bytesToBase64(bytes);
      const id = await this.hashId(base64);
      await this.upsert(new CustomIcon(id, base64));
      return CustomIcon.toIconKey(id);
    } finally {
      try {
        pixelMap.release();
      } catch (_e) {
        // ignore
      }
      try {
        source.release();
      } catch (_e) {
        // ignore
      }
    }
  }

  /**
   * Fallback path when raw bytes are available (e.g. backup import already decoded).
   */
  public async createFromBytes(raw: Uint8Array): Promise<string> {
    const copy = new ArrayBuffer(raw.byteLength);
    new Uint8Array(copy).set(raw);
    const source = image.createImageSource(copy);
    const decodingOptions: image.DecodingOptions = {
      desiredSize: { width: CustomIcon.MaxSize, height: CustomIcon.MaxSize }
    };
    const pixelMap = await source.createPixelMap(decodingOptions);
    try {
      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/png', quality: 100 };
      const packed: ArrayBuffer = await packer.packing(pixelMap, packOpts);
      const bytes = new Uint8Array(packed);
      const base64 = this.bytesToBase64(bytes);
      const id = await this.hashId(base64);
      await this.upsert(new CustomIcon(id, base64));
      return CustomIcon.toIconKey(id);
    } finally {
      try {
        pixelMap.release();
      } catch (_e) {
        // ignore
      }
      try {
        source.release();
      } catch (_e) {
        // ignore
      }
    }
  }

  private async hashId(base64: string): Promise<string> {
    const md = cryptoFramework.createMd('SHA1');
    const bytes = this.stringToUtf8(base64);
    await md.update({ data: bytes });
    const digest = await md.digest();
    const hex = this.bytesToHex(digest.data);
    return hex.substring(0, 8);
  }

  private fieldToString(value: Object | string | undefined | null, fallback: string): string {
    if (value === undefined || value === null) {
      return fallback;
    }
    return String(value);
  }

  private bytesToBase64(bytes: Uint8Array): string {
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(bytes);
  }

  private bytesToHex(bytes: Uint8Array): string {
    let out = '';
    for (let i = 0; i < bytes.length; i++) {
      const h = bytes[i].toString(16);
      out += h.length === 1 ? `0${h}` : h;
    }
    return out;
  }

  private stringToUtf8(value: string): Uint8Array {
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
}
