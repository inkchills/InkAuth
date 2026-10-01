# Harmony Backup Export-to-Disk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make InkAuth’s three backup-menu exports and auto-backup actually land files on disk after the system picker, matching Stratum’s SAF write path.

**Architecture:** Reuse the import-side URI candidate strategy (`UriBytesReader`) for writes. Extract a kit-free candidate helper so unit tests do not need FileUri, then add `UriBytesWriter` that tries those candidates with `CREATE | READ_WRITE | TRUNC`. `Index.saveFile` / auto-backup join a folder URI to a filename and write through that helper. Close overlay menus before `DocumentViewPicker.save` so the save sheet is not eaten by the backup sheet.

**Tech Stack:** HarmonyOS ArkTS, `@kit.CoreFileKit` (`picker`, `fileIo`, `fileUri`), `@ohos/hypium` local unit tests, existing `BackupService` (`createEncryptedBackupAsync` / `createHtmlBackupAsync` / `createUriListBackupAsync`).

**Spec:** `docs/HARMONY_VS_ANDROID_GAP_REPORT.md` — remaining closed-loop item **导出落盘** (backup menu exists; HTML save sheet did not stably appear; write still uses `fs.openSync` on picker URIs). Sibling remaining items (扫码识码、删除/拖拽、应用锁、未支持格式解密、动态颜色/透明状态栏/系统字体/多语言) are **out of scope** and need their own plans.

## Global Constraints

- Keep Android `.stratum` / HTML / URI-list backup formats unchanged; this plan only changes how Harmony writes bytes/strings to the URI the picker returns.
- Do not replace `UriBytesReader`’s read loop; share candidate construction only.
- `dbPasswordBackup` / ranking / import-hint layout work in the gap report is already done; do not reopen it.
- Manual-entry / QR-scan write paths stay untouched unless a compile error forces an import change.
- Local unit tests must stay kit-free (hypium on host). FileUri / picker behavior is verified on-device after the helper is wired.
- File names stay `backup-YYYY-MM-DD_HHMMSS.{stratum|html|txt|json}` from `Index.generateBackupFileName`.

---

## File Structure

- Create: `products/InkAuthApp/src/main/ets/core/util/UriPathCandidates.ets` — pure string candidate list + folder/file join.
- Create: `products/InkAuthApp/src/main/ets/core/util/UriBytesWriter.ets` — try candidates, write bytes or string, last error wins.
- Create: `products/InkAuthApp/src/test/UriPathCandidates.test.ets` — hypium coverage for candidate order and query stripping.
- Modify: `products/InkAuthApp/src/main/ets/core/util/UriBytesReader.ets` — build candidates via `UriPathCandidates.fromUri`.
- Modify: `products/InkAuthApp/src/main/ets/pages/Index.ets` — `saveFile`, auto-backup write, overlay-dismiss delay before picker.
- Modify: `products/InkAuthApp/src/test/List.test.ets` — register the new suite.
- Modify: `docs/HARMONY_VS_ANDROID_GAP_REPORT.md` — mark 导出落盘 closed only after on-device proof.

---

### Task 1: UriPathCandidates helper + unit tests

**Files:**
- Create: `products/InkAuthApp/src/main/ets/core/util/UriPathCandidates.ets`
- Create: `products/InkAuthApp/src/test/UriPathCandidates.test.ets`
- Modify: `products/InkAuthApp/src/test/List.test.ets`

**Interfaces:**
- Consumes: nothing
- Produces: `UriPathCandidates.fromUri(uri: string, extraPath?: string): string[]`; `UriPathCandidates.joinFolder(folderUri: string, fileName: string): string`

- [ ] **Step 1: Write the failing test**

Create `products/InkAuthApp/src/test/UriPathCandidates.test.ets`:

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { UriPathCandidates } from '../main/ets/core/util/UriPathCandidates';

export default function uriPathCandidatesTest() {
  describe('UriPathCandidates', () => {
    it('puts original uri first', 0, () => {
      const out = UriPathCandidates.fromUri('file://docs/currentUser/Download/a.json');
      expect(out[0]).assertEqual('file://docs/currentUser/Download/a.json');
    });

    it('appends extra path when different from uri', 0, () => {
      const out = UriPathCandidates.fromUri(
        'file://docs/currentUser/Download/a.json',
        '/storage/Users/currentUser/Download/a.json'
      );
      expect(out.length).assertEqual(2);
      expect(out[1]).assertEqual('/storage/Users/currentUser/Download/a.json');
    });

    it('does not duplicate extra path when it equals uri', 0, () => {
      const uri = '/data/storage/el2/base/a.json';
      const out = UriPathCandidates.fromUri(uri, uri);
      expect(out.length).assertEqual(1);
    });

    it('strips query as a later candidate', 0, () => {
      const out = UriPathCandidates.fromUri('file://docs/currentUser/Download/a.json?offset=0');
      expect(out[0]).assertEqual('file://docs/currentUser/Download/a.json?offset=0');
      expect(out[out.length - 1]).assertEqual('file://docs/currentUser/Download/a.json');
    });

    it('ignores empty uri', 0, () => {
      const out = UriPathCandidates.fromUri('');
      expect(out.length).assertEqual(0);
    });

    it('joins folder uri and file name without double slash', 0, () => {
      expect(UriPathCandidates.joinFolder('file://docs/currentUser/Download', 'backup.html'))
        .assertEqual('file://docs/currentUser/Download/backup.html');
      expect(UriPathCandidates.joinFolder('file://docs/currentUser/Download/', 'backup.html'))
        .assertEqual('file://docs/currentUser/Download/backup.html');
    });
  });
}
```

Register it in `products/InkAuthApp/src/test/List.test.ets`:

```typescript
import localUnitTest from './LocalUnit.test';
import uriPathCandidatesTest from './UriPathCandidates.test';

export default function testsuite() {
  localUnitTest();
  uriPathCandidatesTest();
}
```

- [ ] **Step 2: Run test to verify it fails**

Run InkAuth local unit tests from DevEco (module `InkAuth`, test type Local Unit) or from `d:\inkauth-dev\stratumauth-harmony`:

```bash
hvigorw --mode module -p module=InkAuth@default -p product=default test
```

Expected: FAIL compiling `UriPathCandidates.test.ets` with `UriPathCandidates` not found (file does not exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `products/InkAuthApp/src/main/ets/core/util/UriPathCandidates.ets`:

```typescript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run the same hypium command as Step 2.

Expected: PASS all `UriPathCandidates` cases. Existing `assertContain` stub in `LocalUnit.test.ets` still passes.

- [ ] **Step 5: Commit**

```bash
git add products/InkAuthApp/src/main/ets/core/util/UriPathCandidates.ets products/InkAuthApp/src/test/UriPathCandidates.test.ets products/InkAuthApp/src/test/List.test.ets
git commit -m "test: add URI candidate helper for Harmony file picker writes"
```

---

### Task 2: Point UriBytesReader at the shared candidate helper

**Files:**
- Modify: `products/InkAuthApp/src/main/ets/core/util/UriBytesReader.ets`

**Interfaces:**
- Consumes: `UriPathCandidates.fromUri(uri, extraPath?)`
- Produces: `UriBytesReader.read(uri: string): Promise<Uint8Array>` unchanged for callers (`ImportSource`, `Index`, `IconPacks`)

- [ ] **Step 1: Write the failing test**

Do not add a FileUri test. Extend `UriPathCandidates.test.ets` with the exact candidate order `UriBytesReader` must feed `openSync` (uri, optional path, stripped query). Already covered in Task 1. This task is a refactor; the failing check is compilation after changing imports.

Add this assertion to `UriPathCandidates.test.ets` so the reader’s order is locked:

```typescript
    it('reader order is uri then path then stripped query', 0, () => {
      const out = UriPathCandidates.fromUri(
        'file://docs/currentUser/Download/a.json?offset=0',
        '/storage/Users/currentUser/Download/a.json'
      );
      expect(out[0]).assertEqual('file://docs/currentUser/Download/a.json?offset=0');
      expect(out[1]).assertEqual('/storage/Users/currentUser/Download/a.json');
      expect(out[2]).assertEqual('file://docs/currentUser/Download/a.json');
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run the hypium command from Task 1.

Expected: FAIL `reader order is uri then path then stripped query` until the test file is saved; after save it should already PASS because `fromUri` was implemented in Task 1. If it passes immediately, continue — the red step for this task is the reader still duplicating candidate logic, which you replace next.

- [ ] **Step 3: Write minimal implementation**

Replace the candidate-building block in `UriBytesReader.read` with:

```typescript
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
  // readFromOpenable unchanged
}
```

Leave `readFromOpenable` as it is today.

- [ ] **Step 4: Run test to verify it passes**

Run the hypium command from Task 1.

Expected: PASS `UriPathCandidates` suite. `UriBytesReader.ets` compiles.

- [ ] **Step 5: Commit**

```bash
git add products/InkAuthApp/src/main/ets/core/util/UriBytesReader.ets products/InkAuthApp/src/test/UriPathCandidates.test.ets
git commit -m "refactor: share picker URI candidates between read and write"
```

---

### Task 3: UriBytesWriter

**Files:**
- Create: `products/InkAuthApp/src/main/ets/core/util/UriBytesWriter.ets`

**Interfaces:**
- Consumes: `UriPathCandidates.fromUri`; `@kit.CoreFileKit` `fileIo` + `fileUri`
- Produces: `UriBytesWriter.write(uri: string, content: string | Uint8Array): Promise<void>`

- [ ] **Step 1: Write the failing test**

Host tests cannot open Harmony picker FDs. Lock the write-mode contract in a comment-level unit by testing folder join used for auto-backup (already in Task 1) and adding a tiny helper test that empty URI yields no candidates so the writer must throw:

```typescript
    it('empty uri has no write candidates', 0, () => {
      expect(UriPathCandidates.fromUri('').length).assertEqual(0);
    });
```

(If this case already exists from Task 1, do not duplicate.)

- [ ] **Step 2: Run test to verify it fails**

Expected: PASS if Task 1 already has `ignores empty uri`. The missing `UriBytesWriter` file is the compile gap for Index in Task 4. Create the writer next.

- [ ] **Step 3: Write minimal implementation**

Create `products/InkAuthApp/src/main/ets/core/util/UriBytesWriter.ets`:

```typescript
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
```

If the SDK’s `OpenMode` has no `TRUNC`, use `fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE` and `fs.truncateSync(file.fd)` before `writeSync`. Do not fall back to `writeFile` with a raw sandbox path concatenation.

- [ ] **Step 4: Run test to verify it passes**

Run hypium. Expected: PASS. Confirm `UriBytesWriter.ets` has no linter errors in DevEco.

- [ ] **Step 5: Commit**

```bash
git add products/InkAuthApp/src/main/ets/core/util/UriBytesWriter.ets
git commit -m "feat: write picker URIs with the same candidate fallback as import"
```

---

### Task 4: Wire Index save + auto-backup + picker timing

**Files:**
- Modify: `products/InkAuthApp/src/main/ets/pages/Index.ets:36-37` (imports)
- Modify: `products/InkAuthApp/src/main/ets/pages/Index.ets:883-966` (`saveFile`, `writeFile`, `exportBackupContent`, `runAutoBackupIfEnabled`)
- Modify: `products/InkAuthApp/src/main/ets/pages/Index.ets:1524-1569` (`onEncryptedBackup` / `confirmExportPassword` / `onHtmlBackup` / `onUriBackup`)

**Interfaces:**
- Consumes: `UriBytesWriter.write(uri, content)`; `UriPathCandidates.joinFolder(folderUri, fileName)`; existing `BackupService.createEncryptedBackupAsync(password: string): Promise<Uint8Array>`, `createHtmlBackupAsync(): Promise<string>`, `createUriListBackupAsync(): Promise<string>`
- Produces: `saveFile` still returns `Promise<boolean>` (false on cancel); toast copy unchanged (`加密备份创建成功` / `HTML备份创建成功` / `URI列表备份创建成功` / `已取消保存` / `备份失败: …`)

- [ ] **Step 1: Write the failing test**

No new hypium case for UI. Add a join test if missing:

```typescript
    it('auto-backup target is folder uri plus generated name', 0, () => {
      const target = UriPathCandidates.joinFolder(
        'file://docs/currentUser/Documents',
        'backup-2026-09-17_160000.stratum'
      );
      expect(target).assertEqual('file://docs/currentUser/Documents/backup-2026-09-17_160000.stratum');
    });
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL only if the test string is not yet added. After adding, PASS. Then change `Index.ets` so the current `fs.openSync(uris[0], READ_WRITE)` path is gone.

- [ ] **Step 3: Write minimal implementation**

1. Add imports next to `UriBytesReader`:

```typescript
import { UriBytesWriter } from '../core/util/UriBytesWriter';
import { UriPathCandidates } from '../core/util/UriPathCandidates';
```

2. Add a private delay used only before picker:

```typescript
  private waitForOverlayDismiss(): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, 300);
    });
  }
```

3. Replace `saveFile`:

```typescript
  private async saveFile(content: string | Uint8Array, fileName: string): Promise<boolean> {
    await this.waitForOverlayDismiss();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.newFileNames = [fileName];
    const documentViewPicker = new picker.DocumentViewPicker(context);
    const uris = await documentViewPicker.save(documentSaveOptions);
    if (!uris || uris.length === 0) {
      return false;
    }
    await UriBytesWriter.write(uris[0], content);
    return true;
  }
```

4. Replace `runAutoBackupIfEnabled` write:

```typescript
      const targetPath = UriPathCandidates.joinFolder(this.autoBackupPath, this.generateBackupFileName(extension));
      await UriBytesWriter.write(targetPath, content);
```

5. Keep `onHtmlBackup` / `onUriBackup` / `confirmExportPassword` calling `exportBackupContent` after they set `showBackupMenu = false` / close the password dialog. Do not open the picker while `showBackupMenu` is true.

6. Delete `writeFile` if nothing else calls it after step 4. If `fs` is unused after that, drop `fileIo as fs` from the Index import and keep `picker`.

- [ ] **Step 4: Run test to verify it passes**

Run hypium. Expected: PASS.

Compile InkAuth in DevEco. Expected: no error on `UriBytesWriter` / `UriPathCandidates` imports; `OpenMode.TRUNC` resolves or the `truncateSync` fallback compiles.

- [ ] **Step 5: Commit**

```bash
git add products/InkAuthApp/src/main/ets/pages/Index.ets products/InkAuthApp/src/test/UriPathCandidates.test.ets
git commit -m "fix: land Harmony backup files through picker URIs"
```

---

### Task 5: On-device closed loop + gap report

**Files:**
- Modify: `docs/HARMONY_VS_ANDROID_GAP_REPORT.md` (only after the three exports write non-empty files)

**Interfaces:**
- Consumes: Tasks 1–4 on a device/emulator with at least one authenticator in the list
- Produces: screenshot/hdc evidence that encrypted `.stratum`, `.html`, and `.txt` exist; report row updated

- [ ] **Step 1: Write the failing test**

On-device checklist (this is the acceptance test; do not mark the report done first):

1. Restore or keep at least one TOTP in the list.
2. Open 备份 → 保存为 HTML 文件. Confirm the system save sheet appears (not an instant return to the list).
3. Save under `Download` or `Documents`. Confirm toast `HTML备份创建成功`.
4. Repeat for URI 列表 (`.txt`) and 加密文件 (password ≥ 4 chars, `.stratum`).
5. `hdc shell` / Files app: each file size > 0. HTML contains `Authenticator Backup`. Encrypted file starts with `AUTHENTICATORPRO`.
6. Optional: Settings 自动备份 → pick a folder → add or edit one authenticator → toast `自动备份已保存` and a new file in that folder.

- [ ] **Step 2: Run test to verify it fails**

If you run this checklist before Task 4 is on the device, expected: HTML still returns to the list without a stable save sheet, or toast `备份失败: No such file or directory` (same class of failure as import `fs.openSync(uri)`).

- [ ] **Step 3: Write minimal implementation**

No extra code if Task 4 already passes on device. If picker still does not show, increase `waitForOverlayDismiss` to 500ms. If write still throws `No such file or directory`, log `candidates` in `UriBytesWriter.write` with `hilog` and add any extra candidate the device actually returns — keep that logic inside `UriPathCandidates.fromUri` so tests can cover the new string shape.

- [ ] **Step 4: Run test to verify it passes**

Re-run the six checklist items. Expected: save sheet visible; three non-empty files; optional auto-backup file.

Then update `docs/HARMONY_VS_ANDROID_GAP_REPORT.md`:

- In the 指标 table, remove 导出落盘 from “仍未真正写入列表的路径” (keep 扫码、删除、拖拽、应用锁 as needed).
- In “本轮写路径测试”, change the HTML 导出 row conclusion to: 鸿蒙保存面板可出现且文件非空.
- In “仍待闭环”, delete 导出落盘.

- [ ] **Step 5: Commit**

```bash
git add docs/HARMONY_VS_ANDROID_GAP_REPORT.md
git commit -m "docs: record Harmony backup export closed loop"
```

---

## Self-Review

1. **Spec coverage:** Gap-report 导出落盘 → Tasks 3–5. HTML 未见保存面板 → Task 4 overlay delay + picker. Auto-backup 写出 → Task 4 `joinFolder` + `UriBytesWriter`. Import URI read already shipped as `UriBytesReader`; Task 2 only shares candidates. 扫码识码、删除/拖拽、应用锁、格式解密、动态颜色/多语言 have no tasks (separate plans).
2. **Placeholder scan:** No TBD / “add error handling” / “similar to Task N”. Test code is inlined.
3. **Type consistency:** `UriPathCandidates.fromUri` / `joinFolder`, `UriBytesWriter.write(uri: string, content: string | Uint8Array): Promise<void>`, `saveFile(...): Promise<boolean>` names match across tasks.
