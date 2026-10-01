import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { IconPack, IconPackEntry } from '../../entity/IconPack';
import { IconResolver } from '../../util/IconResolver';

interface ProtoField {
  fieldNumber: number;
  wireType: number;
}

interface IconPackKeyParts {
  packName: string;
  entryName: string;
}

class ProtoReader {
  private data: Uint8Array;
  private offset: number = 0;

  constructor(data: Uint8Array) {
    this.data = data;
  }

  public eof(): boolean {
    return this.offset >= this.data.length;
  }

  public readField(): ProtoField | null {
    if (this.eof()) {
      return null;
    }
    const tag = this.readVarint();
    const field: ProtoField = { fieldNumber: tag >> 3, wireType: tag & 0x07 };
    return field;
  }

  public readLengthDelimited(): Uint8Array {
    const length = this.readVarint();
    if (length < 0 || this.offset + length > this.data.length) {
      throw new Error('Invalid icon pack length');
    }
    const start = this.offset;
    this.offset += length;
    return this.data.slice(start, start + length);
  }

  public skip(wireType: number): void {
    if (wireType === 0) {
      this.readVarint();
      return;
    }
    if (wireType === 2) {
      this.readLengthDelimited();
      return;
    }
    if (wireType === 5) {
      this.offset += 4;
      return;
    }
    if (wireType === 1) {
      this.offset += 8;
      return;
    }
    throw new Error('Unsupported icon pack field');
  }

  private readVarint(): number {
    let result = 0;
    let shift = 0;
    while (shift < 35) {
      if (this.offset >= this.data.length) {
        throw new Error('Invalid icon pack varint');
      }
      const value = this.data[this.offset++];
      result |= (value & 0x7F) << shift;
      if ((value & 0x80) === 0) {
        return result;
      }
      shift += 7;
    }
    throw new Error('Icon pack varint too large');
  }
}

interface IconPackData {
  name: string;
  description: string;
  url: string;
  icons: Array<IconPackEntry>;
}

export class IconPackService {
  private static instance: IconPackService;
  private static readonly STORE_NAME: string = 'icon_pack_store';
  private static readonly KEY_PACKS: string = 'packs';
  private _store: preferences.Preferences | null = null;
  private _initialized: boolean = false;
  private packs: Array<IconPack> = [];

  private constructor() {}

  public static getInstance(): IconPackService {
    if (!IconPackService.instance) {
      IconPackService.instance = new IconPackService();
    }
    return IconPackService.instance;
  }

  public static toIconKey(packName: string, entryName: string): string {
    return `iconpack:${encodeURIComponent(packName)}:${encodeURIComponent(entryName)}`;
  }

  public async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this._initialized) {
      this.registerIcons();
      return;
    }
    const options: preferences.Options = { name: IconPackService.STORE_NAME };
    this._store = preferences.getPreferencesSync(context, options);
    await this.loadFromStore();
    this._initialized = true;
  }

  public async getAll(): Promise<Array<IconPack>> {
    this.registerIcons();
    return this.packs;
  }

  public async importPackFromBytes(bytes: Uint8Array): Promise<IconPack> {
    const pack = this.parseIconPack(bytes);
    if (!pack.name || pack.icons.length === 0) {
      throw new Error('选择的文件不是有效的图标包（需官方兼容的 .iconpack / protobuf PNG）');
    }

    const existingIndex = this.packs.findIndex((item: IconPack): boolean => item.name === pack.name);
    if (existingIndex >= 0) {
      this.packs[existingIndex] = pack;
    } else {
      this.packs.push(pack);
    }
    await this.saveToStore();
    this.registerIcons();
    return pack;
  }

  public findEntry(packName: string, entryName: string): IconPackEntry | null {
    const pack = this.packs.find((p: IconPack): boolean => p.name === packName);
    if (!pack) {
      return null;
    }
    return pack.icons.find((e: IconPackEntry): boolean => e.name === entryName) || null;
  }

  /**
   * Parse iconpack: key format iconpack:<encPack>:<encName>
   */
  public parseIconKey(iconKey: string): IconPackKeyParts | null {
    if (!iconKey.startsWith('iconpack:')) {
      return null;
    }
    const rest = iconKey.substring('iconpack:'.length);
    const sep = rest.indexOf(':');
    if (sep < 0) {
      return null;
    }
    try {
      const parts: IconPackKeyParts = {
        packName: decodeURIComponent(rest.substring(0, sep)),
        entryName: decodeURIComponent(rest.substring(sep + 1))
      };
      return parts;
    } catch (_e) {
      return null;
    }
  }

  public async deletePack(packName: string): Promise<void> {
    this.packs = this.packs.filter((pack: IconPack): boolean => pack.name !== packName);
    await this.saveToStore();
    this.registerIcons();
  }

  private async loadFromStore(): Promise<void> {
    if (!this._store) {
      return;
    }
    try {
      const json = this._store.getSync(IconPackService.KEY_PACKS, '[]') as string;
      const data = JSON.parse(json) as Array<IconPackData>;
      this.packs = data.map((pack: IconPackData): IconPack => new IconPack(
        pack.name,
        pack.description,
        pack.url,
        (pack.icons || []).map((entry: IconPackEntry): IconPackEntry => {
          const raw = entry.rawBase64 || IconPackService.extractBase64(entry.dataUri);
          const mime = entry.mimeType || IconPackService.extractMime(entry.dataUri);
          const dataUri = entry.dataUri || `data:${mime};base64,${raw}`;
          return new IconPackEntry(pack.name, entry.name, dataUri, raw, mime);
        })
      ));
      this.registerIcons();
    } catch (error) {
      console.error('加载图标包失败:', error);
      this.packs = [];
    }
  }

  private static extractBase64(dataUri: string): string {
    if (!dataUri) {
      return '';
    }
    const idx = dataUri.indexOf('base64,');
    return idx >= 0 ? dataUri.substring(idx + 7) : '';
  }

  private static extractMime(dataUri: string): string {
    if (!dataUri.startsWith('data:')) {
      return 'image/png';
    }
    const semi = dataUri.indexOf(';');
    if (semi > 5) {
      return dataUri.substring(5, semi);
    }
    return 'image/png';
  }

  private async saveToStore(): Promise<void> {
    if (!this._store) {
      return;
    }
    this._store.putSync(IconPackService.KEY_PACKS, JSON.stringify(this.packs));
    await this._store.flush();
  }

  private registerIcons(): void {
    IconResolver.clearIconPackIcons();
    for (const pack of this.packs) {
      for (const entry of pack.icons) {
        IconResolver.registerIconPackIcon(IconPackService.toIconKey(pack.name, entry.name), entry.dataUri);
      }
    }
  }

  private parseIconPack(bytes: Uint8Array): IconPack {
    const reader = new ProtoReader(bytes);
    const pack = new IconPack();
    let skippedSvg = 0;

    while (!reader.eof()) {
      const field = reader.readField();
      if (!field) {
        break;
      }
      if (field.wireType !== 2) {
        reader.skip(field.wireType);
        continue;
      }

      const value = reader.readLengthDelimited();
      if (field.fieldNumber === 1) {
        pack.name = this.bytesToString(value);
      } else if (field.fieldNumber === 2) {
        pack.description = this.bytesToString(value);
      } else if (field.fieldNumber === 3) {
        pack.url = this.bytesToString(value);
      } else if (field.fieldNumber === 4) {
        const entry = this.parseIconPackEntry(value, pack.name);
        if (entry.mimeType === 'image/svg+xml') {
          skippedSvg++;
          continue;
        }
        if (entry.name && entry.dataUri) {
          pack.icons.push(entry);
        }
      }
    }

    for (const entry of pack.icons) {
      entry.iconPackName = pack.name;
    }

    if (pack.icons.length === 0 && skippedSvg > 0) {
      throw new Error('该图标包为 SVG 格式，鸿蒙端请使用 PNG 版 .iconpack（兼容资源见上游 icon-packs 页面）');
    }

    return pack;
  }

  private parseIconPackEntry(bytes: Uint8Array, packName: string): IconPackEntry {
    const reader = new ProtoReader(bytes);
    const entry = new IconPackEntry(packName);

    while (!reader.eof()) {
      const field = reader.readField();
      if (!field) {
        break;
      }
      if (field.wireType !== 2) {
        reader.skip(field.wireType);
        continue;
      }

      const value = reader.readLengthDelimited();
      if (field.fieldNumber === 1) {
        entry.name = this.bytesToString(value);
      } else if (field.fieldNumber === 2) {
        const mime = this.detectMimeType(value);
        if (mime === 'image/svg+xml') {
          entry.mimeType = mime;
          entry.rawBase64 = '';
          entry.dataUri = '';
        } else {
          const b64 = this.bytesToBase64(value);
          entry.mimeType = mime;
          entry.rawBase64 = b64;
          entry.dataUri = `data:${mime};base64,${b64}`;
        }
      }
    }

    return entry;
  }

  private detectMimeType(data: Uint8Array): string {
    if (data.length >= 8 && data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47) {
      return 'image/png';
    }
    if (data.length >= 3 && data[0] === 0xFF && data[1] === 0xD8 && data[2] === 0xFF) {
      return 'image/jpeg';
    }
    if (data.length >= 4 && data[0] === 0x52 && data[1] === 0x49 && data[2] === 0x46 && data[3] === 0x46) {
      return 'image/webp';
    }
    // Detect SVG (text starts with <svg or <?xml)
    if (data.length >= 4) {
      const head = this.bytesToString(data.slice(0, Math.min(64, data.length))).trim().toLowerCase();
      if (head.startsWith('<svg') || head.startsWith('<?xml')) {
        return 'image/svg+xml';
      }
    }
    return 'image/png';
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
      } else {
        result += String.fromCharCode(byte1);
        i++;
      }
    }
    return result;
  }

  private bytesToBase64(data: Uint8Array): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    let index = 0;
    while (index < data.length) {
      const byte1 = data[index++];
      const byte2 = index < data.length ? data[index++] : NaN;
      const byte3 = index < data.length ? data[index++] : NaN;

      result += chars.charAt(byte1 >> 2);
      result += chars.charAt(((byte1 & 0x03) << 4) | (isNaN(byte2) ? 0 : (byte2 >> 4)));
      result += isNaN(byte2) ? '=' : chars.charAt(((byte2 & 0x0F) << 2) | (isNaN(byte3) ? 0 : (byte3 >> 6)));
      result += isNaN(byte3) ? '=' : chars.charAt(byte3 & 0x3F);
    }
    return result;
  }
}