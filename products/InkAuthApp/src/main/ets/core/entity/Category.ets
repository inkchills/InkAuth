// Copyright (C) 2022 jmh
// SPDX-License-Identifier: GPL-3.0-only

export class Category {
  id: string;
  name: string;
  ranking: number;

  constructor(name: string, id?: string, ranking?: number) {
    this.id = id || `${name}_${Date.now()}`;
    this.name = name;
    this.ranking = ranking || 0;
  }
}
