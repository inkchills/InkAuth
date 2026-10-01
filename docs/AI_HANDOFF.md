# InkAuth HarmonyOS AI Handoff

This document captures the current state of the HarmonyOS migration and the important decisions from the Android parity work, so another AI can continue without replaying the full chat history.

## Scope

- Android source of truth in this workspace: `D:\Project\StraumAuth\app\Stratum.Droid`
- HarmonyOS app in this repository: `products/InkAuthApp`
- Current working branch: `harmonyos-refactor`
- Bundle id: `com.inkchills.auth`
- Main ability: `InkAuthAbility`

## Current Validated State

- The HarmonyOS app builds successfully with `build.bat`.
- The app installs and launches on a real HarmonyOS device.
- Encrypted Android `.stratum` backups now import successfully on device.
- The home page UI has been heavily tuned toward Android parity.
- The currently accepted home-page density is to keep 6 authenticator cards visible on one page.
- The main menu sheet has been moved upward so the full menu can be displayed instead of clipping the last item.

## Build And Device Commands

Build from the repository root:

```powershell
$env:DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
.\build.bat
```

Install and launch:

```powershell
$hdc="C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
& $hdc install -r "products\InkAuthApp\build\default\outputs\default\InkAuthApp-default-signed.hap"
& $hdc shell aa start -a InkAuthAbility -b com.inkchills.auth
```

Take a screenshot:

```powershell
$hdc="C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
& $hdc shell snapshot_display -f /data/local/tmp/screen.jpeg
& $hdc file recv /data/local/tmp/screen.jpeg .\screen.jpeg
```

Notes:

- `snapshot_display` must write `.jpeg`, not `.png`.
- If `hdc` reports `need connect-key`, the phone needs USB debugging authorization again.

## Backup Compatibility

Primary implementation file:

- `products/InkAuthApp/src/main/ets/core/service/impl/BackupService.ets`

Important facts:

- Strong Android-compatible `.stratum` backups use the `AUTHENTICATORPRO` header.
- The strong path is Argon2id + AES-256-GCM.
- The working ArkTS import uses named imports from `@ohos-rs/argon2`:

```ts
import { hashRaw, hashRawSync } from "@ohos-rs/argon2";
```

- Do not switch back to a namespace import for `@ohos-rs/argon2`; runtime access to `hashRaw` failed in practice.
- Do not store `Uint8Array` values inside `@State`; ArkUI state handling caused typed-array internal-slot errors during restore work.
- Strong path parameters were aligned to Android Stratum behavior:
  - Argon2id
  - version `0x13`
  - `timeCost = 3`
  - `memoryCost = 65536`
  - `parallelism = 4`
  - `outputLen = 32`
- Legacy encrypted `AuthenticatorPro` imports are also supported.

## UI Parity Notes

Main home-page files:

- `products/InkAuthApp/src/main/ets/pages/Index.ets`
- `products/InkAuthApp/src/main/ets/components/AuthenticatorItem.ets`
- `products/InkAuthApp/src/main/ets/pages/index/components/TopBar.ets`
- `products/InkAuthApp/src/main/ets/pages/index/components/BottomBar.ets`
- `products/InkAuthApp/src/main/ets/components/MainMenu.ets`

Current accepted UI decisions:

- Home page keeps 6 authenticator cards visible in default mode.
- `AuthenticatorItem.ets` currently drives a thicker default card height to fill the screen more aggressively.
- The authenticator code line now starts under the username/title column rather than drifting left.
- The countdown/progress indicator is rendered at the bottom edge of the card, matching the Android visual model more closely than the early Harmony builds.
- The top bar and bottom bar were retuned to resemble the Android screenshot rather than generic Harmony defaults.
- The main menu sheet is explicitly raised using `MainMenu.ets` positioning so all menu items can be displayed.

Current menu positioning detail:

- `MainMenu.ets` uses `.position({ x: 0, y: '24%' })`.

Current list-layout detail:

- `Index.ets` uses a small bottom padding value tuned for the current 6-card layout.

## Signing And Install Notes

- Working signing materials are present under `signing/inkauth_debug` (`inkauth_debug` config).
- Legacy Stratum signing materials are archived under `signing/_archive_stratum/`.
- See `signing/inkauth_debug/README.md` and `scripts/regen-inkauth-debug-signing.ps1`.

## Files Most Likely To Matter Next

- `products/InkAuthApp/src/main/ets/core/service/impl/BackupService.ets`
- `products/InkAuthApp/src/main/ets/pages/Index.ets`
- `products/InkAuthApp/src/main/ets/components/AuthenticatorItem.ets`
- `products/InkAuthApp/src/main/ets/components/MainMenu.ets`
- `products/InkAuthApp/src/main/ets/pages/index/components/BottomBar.ets`
- `products/InkAuthApp/src/main/ets/pages/index/components/TopBar.ets`

## Practical Warnings For Another AI

- Do not reintroduce screenshot debug files at repository root; they were temporary visual-validation artifacts.
- Prefer on-device validation for UI work; screenshot comparison was necessary because purely static tweaks repeatedly missed the Android target.
- If UI density changes again, adjust card height and list bottom padding together; changing only one of them produces misleading empty space or exposes a partial extra item.
- If encrypted import regresses, check `BackupService.ets` first before touching UI code.
- If the main menu looks clipped again, check `MainMenu.ets` sheet position before changing menu item heights.
