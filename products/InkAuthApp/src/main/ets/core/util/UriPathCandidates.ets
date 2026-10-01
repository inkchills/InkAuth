export class UriPathCandidates {
  public static fromUri(uri: string, extraPath?: string): string[] {
    const candidates: string[] = [];
    if (uri && uri.length > 0) {
      candidates.push(uri);
    }
    if (extraPath && extraPath.length > 0 && extraPath !== uri) {
      candidates.push(extraPath);
    }
    const q = uri.indexOf('?');
    if (q > 0) {
      const stripped = uri.substring(0, q);
      if (stripped.length > 0 && candidates.indexOf(stripped) < 0) {
        candidates.push(stripped);
      }
    }
    return candidates;
  }

  public static joinFolder(folderUri: string, fileName: string): string {
    const separator = folderUri.endsWith('/') ? '' : '/';
    return `${folderUri}${separator}${fileName}`;
  }
}
