import { DirectConversationItem, DirectMessage } from '../model/Types';

const KEY_POST_REVISION = 'xsnbb_post_revision';
const KEY_MESSAGE_REVISION = 'xsnbb_message_revision';
const KEY_UNREAD_COUNT = 'xsnbb_unread_count';
const KEY_DIRECT_UNREAD_COUNT = 'xsnbb_direct_unread_count';
const KEY_LATEST_NOTIFICATION_ID = 'xsnbb_latest_notification_id';
const KEY_LATEST_DIRECT_MESSAGE_ID = 'xsnbb_latest_direct_message_id';

/**
 * 跨页面的轻量状态信号。
 *
 * 帖子详情、搜索结果和各内容列表持有不同的数据快照；写操作成功后递增版本号，
 * 各页面通过 @StorageLink 订阅并重新拉取，避免点赞、收藏和评论数只在当前页更新。
 */
export class AppState {
  private static directConversations: DirectConversationItem[] = [];
  private static directSnapshotReady: boolean = false;

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
    AppStorage.setOrCreate<number>(KEY_LATEST_DIRECT_MESSAGE_ID, 0);
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

  /** 同步私信摘要；未读数或最新消息变化时返回 true。 */
  static syncDirectSummary(count: number, latestMessageId: number): boolean {
    const normalizedCount = Math.max(0, count);
    const normalizedLatestId = Math.max(0, latestMessageId);
    const previousCount = AppStorage.get<number>(KEY_DIRECT_UNREAD_COUNT) ?? 0;
    const previousLatestId = AppStorage.get<number>(KEY_LATEST_DIRECT_MESSAGE_ID) ?? 0;
    AppStorage.setOrCreate<number>(KEY_DIRECT_UNREAD_COUNT, normalizedCount);
    AppStorage.setOrCreate<number>(KEY_LATEST_DIRECT_MESSAGE_ID, normalizedLatestId);
    return previousCount !== normalizedCount || previousLatestId !== normalizedLatestId;
  }

  /** 保存服务端会话快照，使底栏数字和消息卡片在同一个状态变更中更新。 */
  static syncDirectConversations(items: DirectConversationItem[], count: number): boolean {
    let latestMessageId = 0;
    items.forEach((conversation: DirectConversationItem) => {
      conversation.messages.forEach((message: DirectMessage) => {
        latestMessageId = Math.max(latestMessageId, message.id);
      });
    });
    AppState.directConversations = [...items];
    AppState.directSnapshotReady = true;
    return AppState.syncDirectSummary(count, latestMessageId);
  }

  static hasDirectSnapshot(): boolean {
    return AppState.directSnapshotReady;
  }

  static directConversationSnapshot(): DirectConversationItem[] {
    return [...AppState.directConversations];
  }

  /** 发送接口响应即写入卡片快照，不等待下一次网络刷新。 */
  static appendDirectMessage(conversationId: number, message: DirectMessage, unlocked: boolean): void {
    if (!AppState.directSnapshotReady) {
      return;
    }
    let updated: DirectConversationItem | undefined = undefined;
    const remaining: DirectConversationItem[] = [];
    AppState.directConversations.forEach((conversation: DirectConversationItem) => {
      if (conversation.id !== conversationId) {
        remaining.push(conversation);
        return;
      }
      const exists = conversation.messages.some((item: DirectMessage) => item.id === message.id);
      updated = {
        id: conversation.id,
        other: conversation.other,
        unlocked: unlocked,
        messages: exists ? conversation.messages : [...conversation.messages, message],
        updated_at: message.created_at,
        unread_count: conversation.unread_count,
      };
    });
    if (updated !== undefined) {
      AppState.directConversations = [updated, ...remaining];
    }
  }

  static markDirectConversationRead(conversationId: number, unread: number): void {
    if (AppState.directSnapshotReady) {
      AppState.directConversations = AppState.directConversations.map((conversation: DirectConversationItem) => {
        if (conversation.id !== conversationId) {
          return conversation;
        }
        return {
          id: conversation.id,
          other: conversation.other,
          unlocked: conversation.unlocked,
          messages: conversation.messages,
          updated_at: conversation.updated_at,
          unread_count: 0,
        };
      });
    }
    AppState.setDirectUnreadCount(unread);
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
