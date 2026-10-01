// SortFilterManager.ets

import { Authenticator } from '../core/entity/Authenticator';

export class SortFilterManager {
  sortAuthenticators(authenticators: Array<Authenticator>, option: string): Array<Authenticator> {
    const sorted = [...authenticators];

    switch (option) {
      case 'alphabetical_asc':
        sorted.sort((a, b) => {
          const issuerA = a.issuer?.toLowerCase() || '';
          const issuerB = b.issuer?.toLowerCase() || '';
          return issuerA.localeCompare(issuerB);
        });
        break;
      case 'alphabetical_desc':
        sorted.sort((a, b) => {
          const issuerA = a.issuer?.toLowerCase() || '';
          const issuerB = b.issuer?.toLowerCase() || '';
          return issuerB.localeCompare(issuerA);
        });
        break;
      case 'copy_count_desc':
        sorted.sort((a, b) => b.copyCount - a.copyCount);
        break;
      case 'copy_count_asc':
        sorted.sort((a, b) => a.copyCount - b.copyCount);
        break;
      case 'custom':
        sorted.sort((a, b) => (a.ranking || 0) - (b.ranking || 0));
        break;
      default:
        sorted.sort((a, b) => (a.ranking || 0) - (b.ranking || 0));
        break;
    }

    return sorted;
  }

  applySearchFilter(authenticators: Array<Authenticator>, searchText: string): Array<Authenticator> {
    if (searchText.trim() === '') {
      return authenticators;
    }

    const searchLower = searchText.toLowerCase();
    return authenticators.filter(auth =>
      (auth.issuer?.toLowerCase() || '').includes(searchLower) ||
      (auth.username?.toLowerCase() || '').includes(searchLower)
    );
  }

  applyCombinedFilters(
    authenticators: Array<Authenticator>,
    searchText: string,
    categoryFiltered: Array<Authenticator>
  ): Array<Authenticator> {
    let filtered = categoryFiltered;

    if (searchText.trim() !== '') {
      const searchLower = searchText.toLowerCase();
      filtered = filtered.filter(auth =>
        (auth.issuer?.toLowerCase() || '').includes(searchLower) ||
        (auth.username?.toLowerCase() || '').includes(searchLower)
      );
    }

    return filtered;
  }
}
