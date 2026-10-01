export class IconPackEntry {
  public iconPackName: string;
  public name: string;
  /** Display source for Image() — data:image/...;base64,... */
  public dataUri: string;
  /** Raw image bytes as Base64 (no data-URI prefix), for CustomIcon conversion. */
  public rawBase64: string;
  public mimeType: string;

  constructor(
    iconPackName: string = '',
    name: string = '',
    dataUri: string = '',
    rawBase64: string = '',
    mimeType: string = 'image/png'
  ) {
    this.iconPackName = iconPackName;
    this.name = name;
    this.dataUri = dataUri;
    this.rawBase64 = rawBase64;
    this.mimeType = mimeType;
  }
}

export class IconPack {
  public name: string;
  public description: string;
  public url: string;
  public icons: Array<IconPackEntry>;

  constructor(name: string = '', description: string = '', url: string = '', icons: Array<IconPackEntry> = []) {
    this.name = name;
    this.description = description;
    this.url = url;
    this.icons = icons;
  }
}
