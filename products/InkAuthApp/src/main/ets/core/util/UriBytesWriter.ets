import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { UriPathCandidates } from './UriPathCandidates';

export class UriBytesWriter {
  public static async write(uri: string, content: string | Uint8Array): Promise<void> {
    let extraPath: string | undefined = undefined;
    try {
      const fu = new fileUri.FileUri(uri);
      const path = fu.path;
      if (path && path.length > 0 && path !== uri) {
        extraPath = path;
      }
    } catch (_e) {
      // ignore FileUri parse errors
    }

    const candidates = UriPathCandidates.fromUri(uri, extraPath);
    let lastError: Error | null = null;
    for (let i = 0; i < candidates.length; i++) {
      try {
        UriBytesWriter.writeToOpenable(candidates[i], content);
        return;
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
      }
    }
    throw lastError || new Error('无法写入所选文件');
  }

  private static writeToOpenable(target: string, content: string | Uint8Array): void {
    const file = fs.openSync(target, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, content);
    } finally {
      fs.closeSync(file);
    }
  }
}
