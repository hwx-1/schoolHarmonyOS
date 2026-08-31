import { Api } from '../../service/Api';
import { ApiError } from '../../service/Http';
import {
  AppNotification,
  ChatParam,
  DirectConversationItem,
  NotificationDetailParam,
  UnreadResp,
} from '../../model/Types';
import { AppColors } from '../../constants/AppConfig';
import { NotificationItemView } from '../business/NotificationItemView';
import { ConversationItemView } from '../business/ConversationItemView';
import { LoadingView } from '../common/LoadingView';
import { EmptyState } from '../common/EmptyState';
import { AppState } from '../../service/AppState';

/** 消息页：系统通知 + 私信会话。 */
@Component
export struct MessagesTab {
  @Consume('navStack') navStack: NavPathStack;
  @StorageLink('xsnbb_message_revision') @Watch('onMessageRevisionChange') messageRevision: number = 0;
  @State segment: number = 0;
  @State notificationFilter: string = 'all';
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State notifications: AppNotification[] = [];
  @State unread: number = 0;
  @State conversations: DirectConversationItem[] = [];

  aboutToAppear(): void {
    this.loadAll();
  }

  private onMessageRevisionChange(): void {
    if (!this.loading) {
      this.loadAll();
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async loadAll(): Promise<void> {
    try {
      const resp = await Api.notifications();
      this.notifications = resp.items;
      this.unread = resp.unread;
      let latestId = 0;
      resp.items.forEach((item: AppNotification) => {
        latestId = Math.max(latestId, item.id);
      });
      AppState.syncNotificationSummary(resp.unread, latestId);
    } catch {
    }
    try {
      const convResp = await Api.listDirectConversations();
      this.conversations = convResp.items;
    } catch {
    }
    this.loading = false;
    this.refreshing = false;
  }

  private async markAllRead(): Promise<void> {
    if (this.unread === 0) {
      return;
    }
    try {
      const resp = await Api.markNotificationsRead([]);
      this.unread = resp.unread;
      this.notifications = this.notifications.map((item: AppNotification) => {
        const copy: AppNotification = {
          id: item.id,
          type: item.type,
          title: item.title,
          body: item.body,
          ref_type: item.ref_type,
          ref_id: item.ref_id,
          read: true,
          created_at: item.created_at,
        };
        return copy;
      });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '操作失败');
    }
  }

  private notificationCategory(type: string): string {
    if (type === 'like' || type === 'bookmark') {
      return 'likes';
    }
    if (type === 'comment' || type === 'reply') {
      return 'comments';
    }
    return 'system';
  }

  private filterCount(filter: string): number {
    return this.notifications.filter((item: AppNotification) =>
      this.notificationCategory(item.type) === filter).length;
  }

  private filteredNotifications(): AppNotification[] {
    if (this.notificationFilter === 'all') {
      return this.notifications;
    }
    return this.notifications.filter((item: AppNotification) =>
      this.notificationCategory(item.type) === this.notificationFilter);
  }

  private readSnapshot(item: AppNotification): AppNotification {
    return {
      id: item.id,
      type: item.type,
      title: item.title,
      body: item.body,
      ref_type: item.ref_type,
      ref_id: item.ref_id,
      read: true,
      created_at: item.created_at,
    };
  }

  private syncReadState(
    itemId: number,
    previousUnread: number,
    previousNotifications: AppNotification[],
  ): void {
    Api.markNotificationsRead([itemId]).then((response: UnreadResp) => {
      this.unread = response.unread;
    }).catch(() => {
      // 服务端失败时回滚未读状态，避免气泡与真实数据不一致。
      this.unread = previousUnread;
      this.notifications = [...previousNotifications];
      AppState.setUnreadCount(previousUnread);
    });
  }

  private openNotification(item: AppNotification): void {
    let detailItem = item;
    if (!item.read) {
      const previousUnread = this.unread;
      const previousNotifications = [...this.notifications];
      detailItem = this.readSnapshot(item);
      this.unread = Math.max(0, this.unread - 1);
      this.notifications = this.notifications.map((notification: AppNotification) => {
        if (notification.id !== item.id) {
          return notification;
        }
        return this.readSnapshot(notification);
      });
      AppState.setUnreadCount(this.unread);
      this.syncReadState(item.id, previousUnread, previousNotifications);
    }
    const param: NotificationDetailParam = { notification: detailItem };
    this.navStack.pushPath({ name: 'NotificationDetail', param: param });
  }

  build() {
    Column() {
      Row() {
        Text('消息')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Blank()
        if (this.segment === 0 && this.unread > 0) {
          Text('全部已读')
            .fontSize(12)
            .fontColor(AppColors.PRIMARY)
            .onClick(() => this.markAllRead())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 2 })

      Row({ space: 24 }) {
        this.MessageTab('通知', 0)
        this.MessageTab('私信', 1)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      if (this.segment === 0) {
        Row({ space: 10 }) {
          this.FilterCard('赞同收藏', '♥', '#E5484D', 'likes')
          this.FilterCard('评论回复', '●', AppColors.PRIMARY, 'comments')
          this.FilterCard('系统通知', '✦', '#7C5CFC', 'system')
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 12, bottom: 10 })

        Row() {
          Text(this.notificationFilter === 'all' ? '最新通知' : '筛选结果')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
          Blank()
          if (this.notificationFilter !== 'all') {
            Text('查看全部')
              .fontSize(12)
              .fontColor(AppColors.PRIMARY)
              .onClick(() => {
                this.notificationFilter = 'all';
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.loading) {
        LoadingView()
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 8 }) {
            if (this.segment === 0) {
              ForEach(this.filteredNotifications(), (item: AppNotification) => {
                ListItem() {
                  NotificationItemView({
                    notification: item,
                    onOpen: (target: AppNotification) => this.openNotification(target)
                  })
                }
              }, (item: AppNotification) => `${item.id}`)
              if (this.filteredNotifications().length === 0) {
                ListItem() {
                  EmptyState({ title: '暂无此类通知', desc: '新的校园互动会出现在这里' })
                }
              }
            } else {
              ListItem() {
                Row({ space: 10 }) {
                  Stack() {
                    Text('✉')
                      .fontSize(18)
                      .fontColor(AppColors.PRIMARY)
                  }
                  .width(40)
                  .height(40)
                  .borderRadius(20)
                  .backgroundColor('#142E6BE6')
                  Column({ space: 2 }) {
                    Text('私信会话')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    Text(`${this.conversations.length} 个最近联系人`)
                      .fontSize(11)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding(14)
                .backgroundColor('#F0F5FF')
                .borderRadius(12)
              }
              ForEach(this.conversations, (item: DirectConversationItem) => {
                ListItem() {
                  ConversationItemView({
                    conversation: item,
                    onOpen: (target: DirectConversationItem) => {
                      const param: ChatParam = { id: target.id, name: target.other.nickname };
                      this.navStack.pushPath({ name: 'Chat', param: param });
                    }
                  })
                }
              }, (item: DirectConversationItem) => `${item.id}`)
              if (this.conversations.length === 0) {
                ListItem() {
                  EmptyState({ title: '暂无私信', desc: '和同学打个招呼吧' })
                }
              }
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 12 })
        }
        .onRefreshing(() => {
          this.refreshing = true;
          this.loadAll();
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  private MessageTab(label: string, index: number) {
    Column({ space: 7 }) {
      Text(label)
        .fontSize(15)
        .fontWeight(this.segment === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.segment === index ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
      Divider()
        .strokeWidth(this.segment === index ? 2 : 0)
        .color(AppColors.PRIMARY)
        .width(32)
    }
    .width(76)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.segment = index;
    })
  }

  @Builder
  private FilterCard(label: string, icon: string, color: string, filter: string) {
    Column({ space: 7 }) {
      Stack() {
        Text(icon)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('#F3F4F8')
      Text(label)
        .fontSize(12)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(`${this.filterCount(filter)} 条`)
        .fontSize(10)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(this.notificationFilter === filter ? '#EDF3FF' : AppColors.CARD_BG)
    .borderRadius(12)
    .border({
      width: this.notificationFilter === filter ? 1 : 0,
      color: this.notificationFilter === filter ? AppColors.PRIMARY : Color.Transparent,
    })
    .onClick(() => {
      this.notificationFilter = this.notificationFilter === filter ? 'all' : filter;
    })
  }
}
