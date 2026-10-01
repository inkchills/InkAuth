// Copyright (C) 2022 jmh
// SPDX-License-Identifier: GPL-3.0-only

import { ICategoryService } from '../ICategoryService';
import { Category } from '../../entity/Category';
import { Authenticator } from '../../entity/Authenticator';
import { AuthenticatorService } from './AuthenticatorService';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 持久化的分类数据接口
 */
interface CategoryData {
  id: string;
  name: string;
  ranking: number;
}

/**
 * 持久化的绑定数据接口
 */
interface BindingsData {
  categoryId: string;
  authenticatorIds: string[];
}

export class CategoryService implements ICategoryService {
  private static instance: CategoryService;
  private categories: Array<Category> = [];
  private bindings: Map<string, Set<string>> = new Map();
  private defaultCategoryId: string | null = null;
  private authenticatorService: AuthenticatorService = AuthenticatorService.getInstance();
  private _store: preferences.Preferences | null = null;
  private _initialized: boolean = false;
  private static readonly STORE_NAME: string = 'category_store';
  private static readonly KEY_CATEGORIES: string = 'categories';
  private static readonly KEY_BINDINGS: string = 'bindings';
  private static readonly KEY_DEFAULT_CATEGORY: string = 'default_category';

  private constructor() {}

  public static getInstance(): CategoryService {
    if (!CategoryService.instance) {
      CategoryService.instance = new CategoryService();
    }
    return CategoryService.instance;
  }

  public async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this._initialized) return;
    try {
      const options: preferences.Options = { name: CategoryService.STORE_NAME };
      this._store = preferences.getPreferencesSync(context, options);
      await this.loadFromStore();
      this._initialized = true;
    } catch (err) {
      console.error('初始化分类存储失败:', err);
    }
  }

  private async loadFromStore(): Promise<void> {
    if (!this._store) return;
    try {
      const catJson = this._store.getSync(CategoryService.KEY_CATEGORIES, '[]') as string;
      const catList: CategoryData[] = JSON.parse(catJson) as CategoryData[];
      this.categories = catList.map((d: CategoryData): Category => new Category(d.name, d.id, d.ranking));

      const bindJson = this._store.getSync(CategoryService.KEY_BINDINGS, '[]') as string;
      const bindList: BindingsData[] = JSON.parse(bindJson) as BindingsData[];
      this.bindings.clear();
      for (const b of bindList) {
        this.bindings.set(b.categoryId, new Set<string>(b.authenticatorIds));
      }

      const defaultCat = this._store.getSync(CategoryService.KEY_DEFAULT_CATEGORY, '') as string;
      this.defaultCategoryId = defaultCat || null;
    } catch (err) {
      console.error('加载分类数据失败:', err);
    }
  }

  private async saveToStore(): Promise<void> {
    if (!this._store) return;
    try {
      const catList: CategoryData[] = [];
      for (const c of this.categories) {
        const item: CategoryData = { id: c.id, name: c.name, ranking: c.ranking };
        catList.push(item);
      }
      this._store.putSync(CategoryService.KEY_CATEGORIES, JSON.stringify(catList));

      const bindList: BindingsData[] = [];
      this.bindings.forEach((authIds: Set<string>, catId: string) => {
        const item: BindingsData = { categoryId: catId, authenticatorIds: Array.from(authIds) };
        bindList.push(item);
      });
      this._store.putSync(CategoryService.KEY_BINDINGS, JSON.stringify(bindList));

      this._store.putSync(CategoryService.KEY_DEFAULT_CATEGORY, this.defaultCategoryId || '');
      await this._store.flush();
    } catch (err) {
      console.error('保存分类数据失败:', err);
    }
  }

  async create(category: Category): Promise<void> {
    const existingCategory = this.categories.find((c: Category): boolean => c.name === category.name);
    if (existingCategory) {
      throw new Error('分类名称已存在');
    }

    const maxRanking = this.categories.length > 0
      ? Math.max(...this.categories.map((c: Category): number => c.ranking))
      : -1;
    category.ranking = maxRanking + 1;

    this.categories.push(category);
    this.bindings.set(category.id, new Set<string>());
    await this.saveToStore();
  }

  async update(category: Category): Promise<void> {
    const index = this.categories.findIndex((c: Category): boolean => c.id === category.id);
    if (index === -1) {
      throw new Error('分类不存在');
    }

    const existingCategory = this.categories.find((c: Category): boolean => c.name === category.name && c.id !== category.id);
    if (existingCategory) {
      throw new Error('分类名称已存在');
    }

    this.categories[index] = category;
    await this.saveToStore();
  }

  async delete(id: string): Promise<void> {
    const index = this.categories.findIndex((c: Category): boolean => c.id === id);
    if (index === -1) {
      throw new Error('分类不存在');
    }

    this.categories.splice(index, 1);
    this.bindings.delete(id);

    if (this.defaultCategoryId === id) {
      this.defaultCategoryId = null;
    }

    // Clear categoryId on authenticators that pointed here
    const authenticators = await this.authenticatorService.getAll();
    for (const auth of authenticators) {
      if (auth.categoryId === id) {
        auth.categoryId = null;
        try {
          await this.authenticatorService.update(auth);
        } catch (err) {
          console.error('清除认证器分类失败:', err);
        }
      }
    }

    await this.saveToStore();
  }

  async getAll(): Promise<Array<Category>> {
    return [...this.categories].sort((a: Category, b: Category): number => a.ranking - b.ranking);
  }

  async getById(id: string): Promise<Category | null> {
    return this.categories.find((c: Category): boolean => c.id === id) || null;
  }

  async addBinding(authenticator: Authenticator, category: Category): Promise<void> {
    const authenticatorId = this.getAuthenticatorId(authenticator);
    const categoryBindings = this.bindings.get(category.id);
    if (categoryBindings) {
      categoryBindings.add(authenticatorId);
    }
    await this.saveToStore();
  }

  async removeBinding(authenticator: Authenticator, category: Category): Promise<void> {
    const authenticatorId = this.getAuthenticatorId(authenticator);
    const categoryBindings = this.bindings.get(category.id);
    if (categoryBindings) {
      categoryBindings.delete(authenticatorId);
    }
    await this.saveToStore();
  }

  async getBindingsForCategory(category: Category): Promise<Array<Authenticator>> {
    const categoryBindings = this.bindings.get(category.id);
    if (!categoryBindings || categoryBindings.size === 0) {
      return [];
    }

    const authenticators = await this.authenticatorService.getAll();
    return authenticators.filter((auth: Authenticator): boolean => categoryBindings.has(this.getAuthenticatorId(auth)));
  }

  async getCategoriesForAuthenticator(authenticator: Authenticator): Promise<Array<Category>> {
    const authenticatorId = this.getAuthenticatorId(authenticator);
    const result: Array<Category> = [];

    this.bindings.forEach((authenticatorIds: Set<string>, categoryId: string) => {
      if (authenticatorIds.has(authenticatorId)) {
        const category = this.categories.find((c: Category): boolean => c.id === categoryId);
        if (category) {
          result.push(category);
        }
      }
    });

    return result;
  }

  async setDefaultCategory(id: string | null): Promise<void> {
    this.defaultCategoryId = id;
    await this.saveToStore();
  }

  async getDefaultCategory(): Promise<string | null> {
    return this.defaultCategoryId;
  }

  async reorder(ids: string[]): Promise<void> {
    let rank = 0;
    for (const id of ids) {
      const category = this.categories.find((c: Category): boolean => c.id === id);
      if (category) {
        category.ranking = rank++;
      }
    }
    await this.saveToStore();
  }

  /**
   * Assign or unassign an authenticator to a category (single-category model used by the list filter).
   */
  async setAuthenticatorCategory(authenticator: Authenticator, categoryId: string | null): Promise<void> {
    const authenticatorId = this.getAuthenticatorId(authenticator);

    // Clear from all category bindings first
    this.bindings.forEach((ids: Set<string>) => {
      ids.delete(authenticatorId);
    });

    authenticator.categoryId = categoryId;
    if (categoryId) {
      let set = this.bindings.get(categoryId);
      if (!set) {
        set = new Set<string>();
        this.bindings.set(categoryId, set);
      }
      set.add(authenticatorId);
    }

    await this.authenticatorService.update(authenticator);
    await this.saveToStore();
  }

  private getAuthenticatorId(authenticator: Authenticator): string {
    return `${authenticator.issuer}:${authenticator.username}:${authenticator.secret}`;
  }
}
