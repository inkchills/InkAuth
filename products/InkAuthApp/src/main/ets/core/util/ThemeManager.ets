// Copyright (C) 2022 jmh
// SPDX-License-Identifier: GPL-3.0-only

export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark',
  BLACK = 'black'
}

export interface ThemeColors {
  background: string;
  surface: string;
  primary: string;
  secondary: string;
  onBackground: string;
  onSurface: string;
  onPrimary: string;
  onSecondary: string;
  border: string;
  divider: string;
  error: string;
  onError: string;
  text: string;
  textSecondary: string;
}

export interface AccentOption {
  id: string;
  label: string;
  lightPrimary: string;
  lightOnPrimary: string;
  darkPrimary: string;
  darkOnPrimary: string;
}

export class ThemeManager {
  private static instance: ThemeManager;
  private currentTheme: ThemeMode = ThemeMode.LIGHT;
  private accentId: string = 'default';
  private listeners: Array<() => void> = [];

  public static readonly ACCENT_OPTIONS: AccentOption[] = [
    {
      id: 'default',
      label: '默认',
      lightPrimary: '#515B92',
      lightOnPrimary: '#FFFFFF',
      darkPrimary: '#BBC3FF',
      darkOnPrimary: '#232C61'
    },
    {
      id: 'blue',
      label: '蓝色',
      lightPrimary: '#1565C0',
      lightOnPrimary: '#FFFFFF',
      darkPrimary: '#90CAF9',
      darkOnPrimary: '#0D47A1'
    },
    {
      id: 'teal',
      label: '青绿',
      lightPrimary: '#00796B',
      lightOnPrimary: '#FFFFFF',
      darkPrimary: '#80CBC4',
      darkOnPrimary: '#004D40'
    },
    {
      id: 'green',
      label: '绿色',
      lightPrimary: '#2E7D32',
      lightOnPrimary: '#FFFFFF',
      darkPrimary: '#A5D6A7',
      darkOnPrimary: '#1B5E20'
    },
    {
      id: 'orange',
      label: '橙色',
      lightPrimary: '#EF6C00',
      lightOnPrimary: '#FFFFFF',
      darkPrimary: '#FFB74D',
      darkOnPrimary: '#E65100'
    },
    {
      id: 'pink',
      label: '粉色',
      lightPrimary: '#C2185B',
      lightOnPrimary: '#FFFFFF',
      darkPrimary: '#F48FB1',
      darkOnPrimary: '#880E4F'
    },
    {
      id: 'purple',
      label: '紫色',
      lightPrimary: '#6A1B9A',
      lightOnPrimary: '#FFFFFF',
      darkPrimary: '#CE93D8',
      darkOnPrimary: '#4A148C'
    }
  ];

  private constructor() {
    this.loadThemeFromStorage();
  }

  public static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  public getTheme(): ThemeMode {
    return this.currentTheme;
  }

  public isDarkLike(): boolean {
    return this.currentTheme === ThemeMode.DARK || this.currentTheme === ThemeMode.BLACK;
  }

  // 判断一组主题色是否为深色配色（按 onBackground 亮度）。
  // 选择 logo 明暗变体时用它而不是 isDarkLike()：它跟随实际渲染的颜色，
  // 主题在组件存活期间切换时也能得到正确结果。
  public static isDarkColorSet(colors: ThemeColors): boolean {
    const hex = colors.onBackground.replace('#', '');
    const r = parseInt(hex.substring(0, 2), 16);
    const g = parseInt(hex.substring(2, 4), 16);
    const b = parseInt(hex.substring(4, 6), 16);
    return (0.299 * r + 0.587 * g + 0.114 * b) > 128;
  }

  public setTheme(theme: ThemeMode): void {
    this.currentTheme = theme;
    this.saveThemeToStorage();
    this.notifyListeners();
  }

  public getAccentId(): string {
    return this.accentId;
  }

  public setAccentId(accentId: string): void {
    const found = ThemeManager.ACCENT_OPTIONS.find((o: AccentOption): boolean => o.id === accentId);
    this.accentId = found ? found.id : 'default';
    this.notifyListeners();
  }

  public toggleTheme(): void {
    this.currentTheme = this.isDarkLike() ? ThemeMode.LIGHT : ThemeMode.DARK;
    this.saveThemeToStorage();
    this.notifyListeners();
  }

  public getColors(): ThemeColors {
    let base: ThemeColors;
    if (this.currentTheme === ThemeMode.BLACK) {
      base = {
        background: '#000000',
        surface: '#121212',
        primary: '#BBC3FF',
        secondary: '#C3C5DD',
        onBackground: '#E4E1E9',
        onSurface: '#E4E1E9',
        onPrimary: '#232C61',
        onSecondary: '#2D2F42',
        border: '#3A3A3A',
        divider: '#2A2A2A',
        error: '#FFB4AB',
        onError: '#690005',
        text: '#E4E1E9',
        textSecondary: '#C7C5D0'
      };
    } else if (this.currentTheme === ThemeMode.DARK) {
      base = {
        background: '#121318',
        surface: '#1D1B20',
        primary: '#BBC3FF',
        secondary: '#C3C5DD',
        onBackground: '#E4E1E9',
        onSurface: '#E4E1E9',
        onPrimary: '#232C61',
        onSecondary: '#2D2F42',
        border: '#90909A',
        divider: '#46464F',
        error: '#FFB4AB',
        onError: '#690005',
        text: '#E4E1E9',
        textSecondary: '#C7C5D0'
      };
    } else {
      base = {
        background: '#FBF8FF',
        surface: '#FFFBFE',
        primary: '#515B92',
        secondary: '#5B5D72',
        onBackground: '#1B1B21',
        onSurface: '#1B1B21',
        onPrimary: '#FFFFFF',
        onSecondary: '#FFFFFF',
        border: '#767680',
        divider: '#C7C5D0',
        error: '#BA1A1A',
        onError: '#FFFFFF',
        text: '#1B1B21',
        textSecondary: '#46464F'
      };
    }

    const accent = ThemeManager.ACCENT_OPTIONS.find((o: AccentOption): boolean => o.id === this.accentId)
      || ThemeManager.ACCENT_OPTIONS[0];
    if (this.isDarkLike()) {
      base.primary = accent.darkPrimary;
      base.onPrimary = accent.darkOnPrimary;
    } else {
      base.primary = accent.lightPrimary;
      base.onPrimary = accent.lightOnPrimary;
    }
    return base;
  }

  public addListener(listener: () => void): void {
    this.listeners.push(listener);
  }

  public removeListener(listener: () => void): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyListeners(): void {
    this.listeners.forEach(listener => listener());
  }

  private saveThemeToStorage(): void {
  }

  private loadThemeFromStorage(): void {
  }
}
