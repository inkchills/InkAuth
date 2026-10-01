// CategoryManager.ets

import { CategoryService } from '../core/service/impl/CategoryService';
import { Category } from '../core/entity/Category';
import { Authenticator } from '../core/entity/Authenticator';

export class CategoryManager {
  private categoryService: CategoryService = CategoryService.getInstance();

  async loadCategories(): Promise<Array<Category>> {
    try {
      const categories = await this.categoryService.getAll();
      return categories;
    } catch (error) {
      console.error('Failed to load categories:', error);
      return [];
    }
  }

  async getDefaultCategoryId(): Promise<string | null> {
    try {
      const defaultCategoryId = await this.categoryService.getDefaultCategory();
      return defaultCategoryId;
    } catch (error) {
      console.error('Failed to get default category:', error);
      return null;
    }
  }

  async getBindingsForCategory(category: Category): Promise<Array<Authenticator>> {
    try {
      const auths = await this.categoryService.getBindingsForCategory(category);
      return auths;
    } catch (error) {
      console.error('Failed to get bindings for category:', error);
      return [];
    }
  }

  async selectCategory(categoryId: string | null, categories: Array<Category>, authenticators: Array<Authenticator>): Promise<Array<Authenticator>> {
    if (!categoryId) {
      return authenticators;
    }

    const category = categories.find(c => c.id === categoryId);
    if (!category) {
      return authenticators;
    }

    try {
      const categoryAuths = await this.getBindingsForCategory(category);
      const categoryAuthIds = new Set(categoryAuths.map(auth =>
        `${auth.issuer}:${auth.username}:${auth.secret}`
      ));

      return authenticators.filter(auth =>
        categoryAuthIds.has(`${auth.issuer}:${auth.username}:${auth.secret}`)
      );
    } catch (error) {
      console.error('Failed to select category:', error);
      return authenticators;
    }
  }

  getCurrentCategoryName(selectedCategoryId: string | null, categories: Array<Category>): string {
    if (!selectedCategoryId) {
      return '全部';
    }

    const category = categories.find(item => item.id === selectedCategoryId);
    return category ? category.name : '全部';
  }
}
