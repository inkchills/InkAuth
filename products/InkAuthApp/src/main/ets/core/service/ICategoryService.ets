// Copyright (C) 2022 jmh
// SPDX-License-Identifier: GPL-3.0-only

import { Category } from '../entity/Category';
import { Authenticator } from '../entity/Authenticator';

export interface ICategoryService {
  create(category: Category): Promise<void>;
  update(category: Category): Promise<void>;
  delete(id: string): Promise<void>;
  getAll(): Promise<Array<Category>>;
  getById(id: string): Promise<Category | null>;
  addBinding(authenticator: Authenticator, category: Category): Promise<void>;
  removeBinding(authenticator: Authenticator, category: Category): Promise<void>;
  getBindingsForCategory(category: Category): Promise<Array<Authenticator>>;
  getCategoriesForAuthenticator(authenticator: Authenticator): Promise<Array<Category>>;
  setDefaultCategory(id: string | null): Promise<void>;
  getDefaultCategory(): Promise<string | null>;
}
