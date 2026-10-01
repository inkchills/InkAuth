// CustomIcon.ets — Android-compatible custom icon entity (@id prefix)

export class CustomIcon {
  public static readonly Prefix: string = '@';
  public static readonly MaxSize: number = 128;

  public id: string;
  /** Raw PNG/JPEG bytes as Base64 (no data-URI prefix). */
  public data: string;

  constructor(id: string = '', data: string = '') {
    this.id = id;
    this.data = data;
  }

  public static toIconKey(id: string): string {
    return `${CustomIcon.Prefix}${id}`;
  }

  public static isCustomIconKey(icon: string | null): boolean {
    return !!icon && icon.startsWith(CustomIcon.Prefix) && !icon.startsWith('data:image/');
  }

  public static extractId(icon: string): string | null {
    if (!CustomIcon.isCustomIconKey(icon)) {
      return null;
    }
    return icon.substring(CustomIcon.Prefix.length);
  }

  public toDataUri(): string {
    // Prefer PNG; Android stores PNG after decode. Detect JPEG magic via base64 prefix.
    const mime = this.data.startsWith('/9j/') ? 'image/jpeg' : 'image/png';
    return `data:${mime};base64,${this.data}`;
  }
}
