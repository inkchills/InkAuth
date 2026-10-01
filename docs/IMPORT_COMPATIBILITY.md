# Import Compatibility

This document tracks parity between the Android import converters and the HarmonyOS import page.

## Current HarmonyOS Support

| Source                 | Android support                          | HarmonyOS status                      | Notes                                                                                                             |
| ---------------------- | ---------------------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Google Authenticator   | Migration QR / URI                       | Supported via scanner / URI text      | File import is guide-only.                                                                                        |
| andOTP                 | Plain JSON, encrypted JSON               | Plain + encrypted supported           | Encrypted: PBKDF2-SHA1 + AES-256-GCM (`ThirdPartyCrypto.decryptAndOtp`).                                          |
| FreeOTP                | Password-protected externalBackup.xml    | Not supported                         | Entry is guide-only to avoid false expectations.                                                                  |
| FreeOTP+               | JSON `tokens`                            | Supported                             | Converts signed-byte secrets to Base32.                                                                           |
| Aegis                  | Plain JSON, encrypted JSON, custom icons | Plain + encrypted + custom icons      | Encrypted: SCrypt password slots + AES-256-GCM (`ThirdPartyCrypto.decryptAegis`).                                 |
| Bitwarden              | Plain JSON, encrypted JSON               | Plain + encrypted supported           | Encrypted: PBKDF2-SHA256 or Argon2id + HKDF-Expand + AES-CBC (`decryptBitwarden`). Folder → first category.       |
| Ente Auth              | URI list/plain data, encrypted data      | URI/plain + encrypted supported       | Encrypted: Argon2id + XChaCha20-Poly1305 secretstream (`decryptEnte`).                                            |
| Proton Authenticator   | JSON `entries`                           | Supported                             | TOTP and Steam entries are supported.                                                                             |
| WinAuth                | Plain URI text, encrypted ZIP            | Plain text supported                  | Encrypted ZIP is not supported yet.                                                                               |
| 2FAS                   | Plain JSON, encrypted services           | Plain + encrypted supported           | Encrypted: PBKDF2-SHA256 + AES-256-GCM (`ThirdPartyCrypto.decryptTwoFas`).                                        |
| KeePass                | KDBX 4 database                          | KDBX 4 + XML/CSV/text URI extract     | KDBX via `KeePassKdbx.decryptKeePassKdbx` (Argon2/AES-KDF, AES-CBC/ChaCha20 outer). KDBX3 / Twofish unsupported. |
| LastPass Authenticator | JSON `accounts`                          | Supported                             | Folder mapping is preserved as the first category.                                                                |
| TOTP Authenticator     | Password-encrypted file                  | Not supported                         | Entry is guide-only.                                                                                              |
| Authenticator Plus     | SQLCipher database                       | Not supported                         | Entry is guide-only.                                                                                              |
| Authy                  | Guide-only                               | Guide-only                            | Same as Android UX.                                                                                               |
| Blizzard Authenticator | Guide/data-file path in Android          | Not supported                         | Entry is guide-only.                                                                                              |
| URI list               | Plain otpauth/motp text                  | Supported                             | HarmonyOS also extracts URIs embedded in XML/CSV/text.                                                            |

## Implementation Notes

- HarmonyOS import dispatch is source-specific in `products/InkAuthApp/src/main/ets/pages/ImportSource.ets`; avoid routing all JSON through generic `items` detection because Bitwarden and Ente can both use `items`.
- Unsupported complex formats are intentionally guide-only or show an unsupported message rather than opening a file picker that will fail later.
- Formats requiring additional crypto/container support remain candidates for future work: FreeOTP, WinAuth ZIP, TOTP Authenticator, Authenticator Plus.
- Encrypted andOTP / 2FAS / Aegis / Bitwarden / Ente are implemented via `core/util/ThirdPartyCrypto.ets`; KeePass KDBX 4 via `core/util/KeePassKdbx.ets`, all wired through the import password dialog.
- Aegis plaintext custom icons (`entry.icon` base64) are restored through `CustomIconService`.
