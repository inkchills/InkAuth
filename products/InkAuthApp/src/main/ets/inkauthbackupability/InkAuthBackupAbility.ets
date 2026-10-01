import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0000;
const LOG_TAG = 'InkAuthBackup';

export default class InkAuthBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    hilog.info(DOMAIN, LOG_TAG, 'System backup preparation completed');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    hilog.info(DOMAIN, LOG_TAG, 'System restore completed, bundleVersion=%{public}s', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}