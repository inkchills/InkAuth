# InkAuth — Android Port Notes

The historical private ArkStratumAuth repository was merged into this workspace and rebranded to **InkAuth**. The complete HarmonyOS app now lives under `products/InkAuthApp`, while the old `entry/src` migration scratch area should be treated as superseded.

## Ported Into This Repository

- Main authenticator list and detail interactions.
- Add, edit, delete, sort, filter, category, and menu flows.
- OTP core generators for TOTP, HOTP, Steam OTP, Yandex OTP, and mOTP.
- Backup and import service scaffolding, including URI handling.
- Settings, guide, intro, about, category, import-source, password, PIN unlock, QR display, and scanner UI pages/components.
- App resources, service icons, SVG actions, adaptive/responsive feature modules, and product-level build profiles.

## Completed During Android Parity Migration

- Android-compatible Stratum backup export now uses the PascalCase schema expected by the Android app, including authenticators, categories, and authenticator-category bindings.
- Strong encrypted `.stratum` export is compatible with Android Stratum's `AUTHENTICATORPRO` format using Argon2id and AES-GCM.
- Import supports plaintext Stratum JSON, URI lists, strong encrypted `.stratum`, and legacy encrypted `AuthenticatorPro` backups.
- Import restores Android authenticator enum values, hash algorithms, HOTP counters, copy counts, rankings, categories, and bindings.
- QR scanning supports regular `otpauth://`, `motp://`, and Google Authenticator `otpauth-migration://offline?data=...` payloads.
- OTP copy now writes to the system pasteboard, updates copy count, and respects tap-to-copy and tap-to-reveal settings.
- HOTP rows expose a counter refresh action; time-based rows expose Android-style skip-to-next refresh when enabled and near expiry.
- The QR code sheet can copy the authenticator URI.
- Settings now drive main-list behavior for tap-to-copy, tap-to-reveal duration, code grouping, username visibility, uncategorized category visibility, view density, screenshot privacy, biometric unlock, and inactivity timeout.
- Automatic backup is triggered after authenticator changes when configured; it writes encrypted `.stratum` backups when an auto-backup password is set, otherwise plaintext JSON.
- HarmonyOS BackupExtensionAbility is registered and uses production log tags; file inclusion remains controlled by `backup_config.json`.
- Removed unused migration scratch UI and misleading placeholder flows.

## Completed Gap Fixes (2026-08)

- Authenticator Preferences now prefer `encrypt: true` (with one-time migration from the legacy plaintext store).
- Password hashes upgraded to SHA-256 (legacy hashes migrate on successful unlock).
- Custom icons: gallery pick, `@id` keys, encrypted Preferences storage, and `CustomIcons` backup import/export.
- Custom list sort now uses ranking; long-press drag reorder + lock/unlock ordering.
- Deep links for `otpauth` / `otpauth-migration` / `motp` registered on the main ability.
- HTML backup embeds SVG QR codes (not URI-only).
- Settings timeout is gated by password (app lock), not tap-to-reveal; added reset copy counts.
- Password setting copy no longer claims full SQLCipher-style DB encryption.
- Categories page: assign authenticators, set default, drag reorder.
- Encrypted andOTP + 2FAS imports; Aegis plain custom-icon restore.
- Encrypted Aegis (SCrypt + AES-GCM), Bitwarden (PBKDF2/Argon2 + HKDF + AES-CBC), and Ente Auth (Argon2id + XChaCha20) imports via password dialog.
- KeePass KDBX 4 import (`KeePassKdbx.decryptKeePassKdbx`) plus XML/CSV/text URI fallback.
- About / Icon Packs pages link to GitHub, website, and icon-pack downloads.
- Icon packs: accept official `.iconpack`; reject SVG payloads; applying a pack icon creates Android-compatible `@id` CustomIcon (PNG) instead of storing a raw data URI.
- i18n scaffolding: Chinese (`base`) + English (`en_US`) string resources, `LanguageManager` (persist in `settings_prefs`, apply via `ApplicationContext.setLanguage`), and Settings language picker (Follow system / 中文 / English).

## Build And Signing

- A project-local debug signing configuration named `inkauth_debug` is configured in the top-level `build-profile.json5`.
- The signing materials live under `signing/inkauth_debug` (`CN=InkAuth Debug`) and are bound to the app bundle `com.inkchills.auth`.
- Legacy Stratum-named debug materials were moved to `signing/_archive_stratum/` and are unused. Regenerate with `scripts/regen-inkauth-debug-signing.ps1` if needed. Do not use these for AppGallery release.
- Build from the repository root with:

```powershell
$env:DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
.\build.bat
```

- The current CLI build reaches ArkTS compile, HAP packaging, signing, and `assembleHap` successfully.

## Still Needs Platform Verification

- Device camera QR scanning against real HarmonyOS camera permissions and APIs.
- Secure storage and biometric behavior on actual devices.
- Backup/restore file picker flows and encrypted backup compatibility with Android Stratum files.
- Automatic backup folder URI write access on target HarmonyOS devices. The app attempts direct writes to the folder URI returned by the picker, but this depends on platform capability and user-granted access.
- Google Authenticator migration QR import with a real multi-account export payload.
- HarmonyOS system backup/restore lifecycle with `InkAuthBackupAbility` and `backup_config.json`.
- Installation and runtime checks of the signed debug HAP on a real HarmonyOS device.

## Known Platform Difference

- Android's "database password backup" option reuses the database password stored in Android secure storage as the backup encryption password. The current HarmonyOS password service stores only a verification hash, so the HarmonyOS settings page does not expose this option. Manual encrypted backups and automatic encrypted backups both use an explicit backup password instead.

## Crypto Implementation Notes

- Keep strong backup encryption on `@ohos-rs/argon2` plus `@kit.CryptoArchitectureKit` AES-GCM unless a verified replacement supports Android's exact Argon2id parameters and GCM tag layout. This preserves compatibility with Android Stratum `.stratum` files.
- `@ohos/crypto-js` can be used for JS-level helpers or legacy PBKDF2/AES-CBC experiments, but it should not replace the strong backup path because the Android format depends on Argon2id and AES-GCM.
- The local shell PATH currently does not expose `ohpm`; adding `@ohos/crypto-js` should be done through DevEco Studio or a configured ohpm command, followed by a full `build.bat` verification.

## Git State

- `arkstratum/main` was fetched through the local HTTP proxy and merged into `harmonyos-refactor`.
- The older temporary migration stash is intentionally kept as `pre-arkstratumauth-merge-2026-05-18`; do not apply it wholesale unless you specifically want to restore the superseded `entry/src` scratch implementation.
