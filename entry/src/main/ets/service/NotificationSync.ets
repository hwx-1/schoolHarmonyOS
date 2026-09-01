import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppNotification } from '../model/Types';
import { Api } from './Api';
import { AppState } from './AppState';
import { Session } from './Session';

const TAG = 'NotificationSync';
const DOMAIN = 0x0001;

const NOTIFICATION_POLL_INTERVAL_MS = 3000;

/**
 * 前台通知同步：服务端产生点赞/评论通知后，在一个轮询周期内刷新消息列表与底栏红点。
 * 后续接入推送或 WebSocket 时可保留此服务作为断线兜底。
 */
export class NotificationSync {
  private static timerId: number = -1;
  private static syncing: boolean = false;

  static start(): void {
    if (NotificationSync.timerId >= 0) {
      return;
    }
    NotificationSync.syncNow();
    NotificationSync.timerId = setInterval(() => {
      NotificationSync.syncNow();
    }, NOTIFICATION_POLL_INTERVAL_MS);
  }

  static stop(): void {
    if (NotificationSync.timerId >= 0) {
      clearInterval(NotificationSync.timerId);
      NotificationSync.timerId = -1;
    }
  }

  static async syncNow(): Promise<void> {
    const autoSyncEnabled = AppStorage.get<boolean>('xsnbb_notification_auto_sync_enabled') ?? true;
    if (NotificationSync.syncing || !Session.isLoggedIn() || !autoSyncEnabled) {
      return;
    }
    NotificationSync.syncing = true;
    let changed = false;
    try {
      const response = await Api.notifications();
      let latestId = 0;
      response.items.forEach((item: AppNotification) => {
        latestId = Math.max(latestId, item.id);
      });
      changed = AppState.syncNotificationSummary(response.unread, latestId) || changed;
    } catch (e) {
      // 网络异常时保留现有未读状态，下一个轮询周期自动重试；保留日志便于联调定位
      hilog.error(DOMAIN, TAG, `syncNow failed: ${(e as Error).message}`);
    }
    try {
      const response = await Api.listDirectConversations();
      changed = AppState.syncDirectConversations(response.items, response.unread) || changed;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `sync direct messages failed: ${(e as Error).message}`);
    }
    if (changed) {
      AppState.publishMessageChange();
    }
    NotificationSync.syncing = false;
  }
}
