import { hilog } from '@kit.PerformanceAnalysisKit';
import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import {
  AppNotification,
  NotificationDetailParam,
  UnreadResp,
} from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { NotificationItemView } from '../components/business/NotificationItemView';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { NavBar } from '../components/common/NavBar';
import { AppState } from '../service/AppState';

const TAG = 'NotificationsPage';
const DOMAIN = 0x0001;

/** 互动通知列表页：消息页「互动通知」入口卡片点入后展示（抖音私信模式）。 */
@Component
export struct NotificationsPage {
  @Consume('navStack') navStack: NavPathStack;
  @StorageLink('xsnbb_message_revision') @Watch('onMessageRevisionChange') messageRevision: number = 0;
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State notifications: AppNotification[] = [];
  @State unread: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private onMessageRevisionChange(): void {
    if (!this.loading) {
      this.load();
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async load(): Promise<void> {
    try {
      const resp = await Api.notifications();
      // 服务端按 map 遍历返回，顺序不稳定，统一按时间倒序展示
      this.notifications = resp.items.sort((a: AppNotification, b: AppNotification) =>
        b.created_at.localeCompare(a.created_at));
      this.unread = resp.unread;
      let latestId = 0;
      resp.items.forEach((item: AppNotification) => {
        latestId = Math.max(latestId, item.id);
      });
      AppState.syncNotificationSummary(resp.unread, latestId);
    } catch (e) {
      // 通知加载失败保留现有列表；保留日志便于联调定位
      hilog.error(DOMAIN, TAG, `load notifications failed: ${(e as Error).message}`);
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
      this.notifications = this.notifications.map((item: AppNotification) => this.readSnapshot(item));
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '操作失败');
    }
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
    }).catch((e: Error) => {
      // 服务端失败时回滚未读状态，避免气泡与真实数据不一致。
      hilog.error(DOMAIN, TAG, `markNotificationRead failed: ${e.message}`);
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
    NavDestination() {
      Column() {
        NavBar({
          title: '互动通知',
          rightText: this.unread > 0 ? '全部已读' : '',
          rightFontSize: 12,
          onBack: () => {
            this.navStack.pop();
          },
          onRight: () => {
            this.markAllRead();
          }
        })

        if (this.loading) {
          LoadingView()
        } else {
          Refresh({ refreshing: $$this.refreshing }) {
            List({ space: 8 }) {
              ForEach(this.notifications, (item: AppNotification) => {
                ListItem() {
                  NotificationItemView({
                    notification: item,
                    onOpen: (target: AppNotification) => this.openNotification(target)
                  })
                }
              // 键值带上已读态：否则已读后组件复用旧 @Prop，卡片仍显示未读样式。
              }, (item: AppNotification) => `${item.id}:${item.read ? 1 : 0}`)

              if (this.notifications.length === 0) {
                ListItem() {
                  EmptyState({ title: '暂无通知', desc: '点赞、评论等校园互动会出现在这里' })
                }
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 4, bottom: 12 })
          }
          .onRefreshing(() => {
            this.refreshing = true;
            this.load();
          })
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
