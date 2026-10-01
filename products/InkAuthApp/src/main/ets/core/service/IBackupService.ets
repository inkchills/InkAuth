// IBackupService.ets

export interface IBackupService {
  createBackupAsync(): Promise<Uint8Array>;
  createEncryptedBackupAsync(password: string): Promise<Uint8Array>;
  createHtmlBackupAsync(): Promise<string>;
  createUriListBackupAsync(): Promise<string>;

}
