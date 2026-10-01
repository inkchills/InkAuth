import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { UriPathCandidates } from './UriPathCandidates';

export class UriBytesReader {
  public static async read(uri: string): Promise<Uint8Array> {
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
        return UriBytesReader.readFromOpenable(candidates[i]);
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
      }
    }
    throw lastError || new Error('无法读取所选文件');
  }

  private static readFromOpenable(target: string): Uint8Array {
    const file = fs.openSync(target, fs.OpenMode.READ_ONLY);
    try {
      let size = 0;
      try {
        size = fs.statSync(file.fd).size;
      } catch (_statFdError) {
        try {
          size = fs.statSync(target).size;
        } catch (_statPathError) {
          size = 0;
        }
      }
      if (size > 0) {
        const buffer = new ArrayBuffer(size);
        let totalRead = 0;
        while (totalRead < size) {
          const readLength = fs.readSync(file.fd, buffer, { offset: totalRead, length: size - totalRead });
          if (readLength <= 0) {
            throw new Error(`文件读取不完整: ${totalRead}/${size}`);
          }
          totalRead += readLength;
        }
        return new Uint8Array(buffer);
      }
      const chunks: Uint8Array[] = [];
      let total = 0;
      while (true) {
        const tmp = new ArrayBuffer(64 * 1024);
        const n = fs.readSync(file.fd, tmp);
        if (n <= 0) {
          break;
        }
        chunks.push(new Uint8Array(tmp.slice(0, n)));
        total += n;
      }
      if (total <= 0) {
        throw new Error('文件为空');
      }
      const out = new Uint8Array(total);
      let offset = 0;
      for (let i = 0; i < chunks.length; i++) {
        out.set(chunks[i], offset);
        offset += chunks[i].length;
      }
      return out;
    } finally {
      fs.closeSync(file);
    }
  }
}
