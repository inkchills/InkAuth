import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { LanguageManager } from '../core/util/LanguageManager';

const DOMAIN = 0x0000;
const LOG_TAG = 'InkAuthAbility';
const PENDING_OTP_URI_KEY: string = 'pendingOtpUri';

export default class InkAuthAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate('insetTopPx', 0);
    AppStorage.setOrCreate('insetBottomPx', 0);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, LOG_TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    this.captureOtpUriFromWant(want);
    hilog.info(DOMAIN, LOG_TAG, '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.captureOtpUriFromWant(want);
    hilog.info(DOMAIN, LOG_TAG, '%{public}s', 'Ability onNewWant');
  }

  private captureOtpUriFromWant(want: Want): void {
    try {
      const uri = want?.uri || '';
      if (!uri) {
        return;
      }
      if (uri.startsWith('otpauth://') || uri.startsWith('otpauth-migration://') || uri.startsWith('motp://')) {
        AppStorage.setOrCreate(PENDING_OTP_URI_KEY, uri);
        hilog.info(DOMAIN, LOG_TAG, 'Captured OTP deep link');
      }
    } catch (err) {
      hilog.error(DOMAIN, LOG_TAG, 'captureOtpUriFromWant failed: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, LOG_TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, LOG_TAG, '%{public}s', 'Ability onWindowStageCreate');
    this.loadMainContent(windowStage);
  }

  private async loadMainContent(windowStage: window.WindowStage): Promise<void> {
    try {
      await LanguageManager.getInstance().initialize(this.context);
    } catch (err) {
      hilog.error(DOMAIN, LOG_TAG, 'LanguageManager init failed: %{public}s', JSON.stringify(err));
    }

    try {
      const mainWindow = await windowStage.getMainWindow();
      this.mainWindow = mainWindow;
      // Immersive layout: draw under status / gesture bars, then pad content via AppStorage insets.
      await mainWindow.setWindowLayoutFullScreen(true);
      // Match nav strip to bottom bar surface so any residual gap blends in.
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#1D1B20',
        statusBarContentColor: '#E4E1E9',
        navigationBarContentColor: '#E4E1E9'
      });
      this.publishAvoidInsets(mainWindow);
      mainWindow.on('avoidAreaChange', () => {
        if (this.mainWindow) {
          this.publishAvoidInsets(this.mainWindow);
        }
      });
      // Re-measure after content is up (first read can be 0 on some devices).
      setTimeout(() => {
        if (this.mainWindow) {
          this.publishAvoidInsets(this.mainWindow);
        }
      }, 300);
    } catch (err) {
      hilog.error(DOMAIN, LOG_TAG, 'Failed to configure immersive window. Cause: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, LOG_TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, LOG_TAG, 'Succeeded in loading the content.');
    });
  }

  private publishAvoidInsets(mainWindow: window.Window): void {
    try {
      const systemAvoid = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navAvoid = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const topPx = systemAvoid.topRect.height;
      const bottomPx = Math.max(navAvoid.bottomRect.height, systemAvoid.bottomRect.height);
      AppStorage.setOrCreate('insetTopPx', topPx);
      AppStorage.setOrCreate('insetBottomPx', bottomPx);
      hilog.info(DOMAIN, LOG_TAG, 'insets top=%{public}d bottom=%{public}d', topPx, bottomPx);
    } catch (err) {
      hilog.error(DOMAIN, LOG_TAG, 'publishAvoidInsets failed: %{public}s', JSON.stringify(err));
      AppStorage.setOrCreate('insetTopPx', 0);
      AppStorage.setOrCreate('insetBottomPx', 0);
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, LOG_TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, LOG_TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, LOG_TAG, '%{public}s', 'Ability onBackground');
  }
}
