// Copyright (C) 2022 jmh
// SPDX-License-Identifier: GPL-3.0-only

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { i18n } from '@kit.LocalizationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF00;
const LOG_TAG = 'LanguageManager';
const PREFS_NAME = 'settings_prefs';
const LANGUAGE_KEY = 'language';

export type AppLanguage = 'system' | 'zh' | 'en';

/**
 * Persists language preference and applies it via ApplicationContext / LocalizationKit.
 */
export class LanguageManager {
  private static instance: LanguageManager;
  private language: AppLanguage = 'system';
  private initialized: boolean = false;

  private constructor() {
  }

  public static getInstance(): LanguageManager {
    if (!LanguageManager.instance) {
      LanguageManager.instance = new LanguageManager();
    }
    return LanguageManager.instance;
  }

  public async initialize(context: common.Context): Promise<void> {
    try {
      const options: preferences.Options = { name: PREFS_NAME };
      const store = await preferences.getPreferences(context, options);
      const saved = (await store.get(LANGUAGE_KEY, 'system')) as string;
      this.language = this.normalize(saved);
      this.initialized = true;
      this.applyLanguage(context, this.language);
      hilog.info(DOMAIN, LOG_TAG, 'Initialized language=%{public}s', this.language);
    } catch (err) {
      hilog.error(DOMAIN, LOG_TAG, 'initialize failed: %{public}s', JSON.stringify(err));
      this.language = 'system';
      this.initialized = true;
    }
  }

  public getLanguage(): AppLanguage {
    return this.language;
  }

  public isInitialized(): boolean {
    return this.initialized;
  }

  public async setLanguage(lang: AppLanguage, context: common.Context): Promise<void> {
    const normalized = this.normalize(lang);
    this.language = normalized;
    try {
      const options: preferences.Options = { name: PREFS_NAME };
      const store = await preferences.getPreferences(context, options);
      await store.put(LANGUAGE_KEY, normalized);
      await store.flush();
    } catch (err) {
      hilog.error(DOMAIN, LOG_TAG, 'save language failed: %{public}s', JSON.stringify(err));
    }
    this.applyLanguage(context, normalized);
  }

  private applyLanguage(context: common.Context, lang: AppLanguage): void {
    const localeTag = this.toLocaleTag(lang);
    try {
      // Empty string follows system language (API 12+)
      context.getApplicationContext().setLanguage(localeTag);
      hilog.info(DOMAIN, LOG_TAG, 'setLanguage(%{public}s)', localeTag.length === 0 ? 'system' : localeTag);
      return;
    } catch (err) {
      hilog.warn(DOMAIN, LOG_TAG, 'ApplicationContext.setLanguage failed: %{public}s', JSON.stringify(err));
    }

    try {
      if (lang === 'system') {
        i18n.System.setAppPreferredLanguage(i18n.System.getSystemLanguage());
      } else {
        i18n.System.setAppPreferredLanguage(localeTag);
      }
      hilog.info(DOMAIN, LOG_TAG, 'setAppPreferredLanguage fallback applied');
    } catch (err2) {
      hilog.error(DOMAIN, LOG_TAG, 'setAppPreferredLanguage failed: %{public}s', JSON.stringify(err2));
    }
  }

  private toLocaleTag(lang: AppLanguage): string {
    if (lang === 'zh') {
      return 'zh-Hans';
    }
    if (lang === 'en') {
      return 'en-US';
    }
    return '';
  }

  private normalize(value: string): AppLanguage {
    if (value === 'zh' || value === 'en' || value === 'system') {
      return value;
    }
    return 'system';
  }
}
