const KEY_POST_REVISION = 'xsnbb_post_revision';
const KEY_MESSAGE_REVISION = 'xsnbb_message_revision';
const KEY_UNREAD_COUNT = 'xsnbb_unread_count';
const KEY_DIRECT_UNREAD_COUNT = 'xsnbb_direct_unread_count';
const KEY_LATEST_NOTIFICATION_ID = 'xsnbb_latest_notification_id';

/**
 * 跨页面的轻量状态信号。
 *
 * 帖子详情、搜索结果和各内容列表持有不同的数据快照；写操作成功后递增版本号，
 * 各页面通过 @StorageLink 订阅并重新拉取，避免点赞、收藏和评论数只在当前页更新。
 */
export class AppState {
  static initialize(): void {
    // 用户偏好使用 PersistentStorage 持久化，并同步到 AppStorage 供页面订阅。
    PersistentStorage.persistProp('xsnbb_privacy_agreed', false);
    PersistentStorage.persistProp('xsnbb_in_app_notification_enabled', true);
    PersistentStorage.persistProp('xsnbb_notification_badge_enabled', true);
    PersistentStorage.persistProp('xsnbb_notification_auto_sync_enabled', true);
    AppStorage.setOrCreate<number>(KEY_POST_REVISION, 0);
    AppStorage.setOrCreate<number>(KEY_MESSAGE_REVISION, 0);
    AppStorage.setOrCreate<number>(KEY_UNREAD_COUNT, 0);
    AppStorage.setOrCreate<number>(KEY_DIRECT_UNREAD_COUNT, 0);
    AppStorage.setOrCreate<number>(KEY_LATEST_NOTIFICATION_ID, 0);
  }

  static publishPostChange(): void {
    const revision = AppStorage.get<number>(KEY_POST_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(KEY_POST_REVISION, revision + 1);
  }

  static requestPostRefresh(): void {
    AppState.publishPostChange();
  }

  static publishMessageChange(): void {
    const revision = AppStorage.get<number>(KEY_MESSAGE_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(KEY_MESSAGE_REVISION, revision + 1);
  }

  static requestMessageRefresh(): void {
    AppState.publishMessageChange();
  }

  static setUnreadCount(count: number): void {
    const normalized = Math.max(0, count);
    if ((AppStorage.get<number>(KEY_UNREAD_COUNT) ?? 0) !== normalized) {
      AppStorage.setOrCreate<number>(KEY_UNREAD_COUNT, normalized);
    }
  }

  /** 私信未读数：与通知未读分开存储，底栏冒泡展示两者合计。 */
  static setDirectUnreadCount(count: number): void {
    const normalized = Math.max(0, count);
    if ((AppStorage.get<number>(KEY_DIRECT_UNREAD_COUNT) ?? 0) !== normalized) {
      AppStorage.setOrCreate<number>(KEY_DIRECT_UNREAD_COUNT, normalized);
    }
  }

  /** 同步通知摘要；未读数或最新通知变化时返回 true。 */
  static syncNotificationSummary(count: number, latestNotificationId: number): boolean {
    const normalizedCount = Math.max(0, count);
    const normalizedLatestId = Math.max(0, latestNotificationId);
    const previousCount = AppStorage.get<number>(KEY_UNREAD_COUNT) ?? 0;
    const previousLatestId = AppStorage.get<number>(KEY_LATEST_NOTIFICATION_ID) ?? 0;
    AppStorage.setOrCreate<number>(KEY_UNREAD_COUNT, normalizedCount);
    AppStorage.setOrCreate<number>(KEY_LATEST_NOTIFICATION_ID, normalizedLatestId);
    return previousCount !== normalizedCount || previousLatestId !== normalizedLatestId;
  }
}
