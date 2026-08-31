import { hilog } from '@kit.PerformanceAnalysisKit';
import { Api } from '../../service/Api';
import {
  AppNotification,
  ChatParam,
  DirectConversationItem,
  DirectMessage,
} from '../../model/Types';
import { AppColors } from '../../constants/AppConfig';
import { ConversationItemView } from '../business/ConversationItemView';
import { LoadingView } from '../common/LoadingView';
import { EmptyState } from '../common/EmptyState';
import { NavBar } from '../common/NavBar';
import { AppState } from '../../service/AppState';
import { Session } from '../../service/Session';

const TAG = 'MessagesTab';
const DOMAIN = 0x0001;

/**
 * 消息页（抖音私信模式）：
 * 顶部「互动通知」聚合入口卡片（带未读冒泡与最新一条预览），点入才展示通知列表；
 * 下方每个私信会话各为一张独立入口卡片。
 */
@Component
export struct MessagesTab {
  @Consume('navStack') navStack: NavPathStack;
  @StorageLink('xsnbb_message_revision') @Watch('onMessageRevisionChange') messageRevision: number = 0;
  @StorageProp('xsnbb_unread_count') noticeUnread: number = 0;
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State conversations: DirectConversationItem[] = [];
  /** 最新一条互动通知标题，作为入口卡片预览文案。 */
  @State latestNotice: string = '';

  aboutToAppear(): void {
    this.loadAll();
  }

  private onMessageRevisionChange(): void {
    if (!this.loading) {
      this.loadAll();
    }
  }

  private async loadAll(): Promise<void> {
    try {
      const resp = await Api.notifications();
      let latestId = 0;
      let latestAt = '';
      let latestTitle = '';
      resp.items.forEach((item: AppNotification) => {
        latestId = Math.max(latestId, item.id);
        if (item.created_at >= latestAt) {
          latestAt = item.created_at;
          latestTitle = item.title;
        }
      });
      this.latestNotice = latestTitle;
      AppState.syncNotificationSummary(resp.unread, latestId);
    } catch (e) {
      // 通知摘要加载失败保留现有状态；保留日志便于联调定位
      hilog.error(DOMAIN, TAG, `loadAll notifications failed: ${(e as Error).message}`);
    }
    try {
      const convResp = await Api.listDirectConversations();
      this.conversations = convResp.items;
      AppState.setDirectUnreadCount(this.unreadDirectCount());
    } catch (e) {
      // 会话加载失败保留现有列表；保留日志便于联调定位
      hilog.error(DOMAIN, TAG, `loadAll conversations failed: ${(e as Error).message}`);
    }
    this.loading = false;
    this.refreshing = false;
  }

  /** 私信未读数：所有会话中对方发来且状态不是已读的消息总数。 */
  private unreadDirectCount(): number {
    let count = 0;
    this.conversations.forEach((conversation: DirectConversationItem) => {
      count += this.unreadOfConversation(conversation);
    });
    return count;
  }

  /** 单个会话的未读数：对方发来且状态不是已读的消息条数（作为原始类型传给卡片，保证随状态刷新）。 */
  private unreadOfConversation(conversation: DirectConversationItem): number {
    const myId = Session.currentAccount()?.id ?? -1;
    let count = 0;
    conversation.messages.forEach((message: DirectMessage) => {
      if (message.sender_id !== myId && message.status !== 'read') {
        count++;
      }
    });
    return count;
  }

  /** 进入会话后本地立即把对方消息置为已读，未读数冒泡即时消失；服务端状态由聊天页已读协议持久化。 */
  private markConversationMessagesRead(conversationId: number): void {
    const myId = Session.currentAccount()?.id ?? -1;
    this.conversations = this.conversations.map((conversation: DirectConversationItem) => {
      if (conversation.id !== conversationId) {
        return conversation;
      }
      const copy: DirectConversationItem = {
        id: conversation.id,
        other: conversation.other,
        unlocked: conversation.unlocked,
        updated_at: conversation.updated_at,
        messages: conversation.messages.map((message: DirectMessage) => {
          if (message.sender_id === myId || message.status === 'read') {
            return message;
          }
          const messageCopy: DirectMessage = {
            id: message.id,
            sender_id: message.sender_id,
            text: message.text,
            system: message.system,
            status: 'read',
            created_at: message.created_at,
          };
          return messageCopy;
        }),
      };
      return copy;
    });
    // 底栏冒泡立即更新，不等待下次拉取
    AppState.setDirectUnreadCount(this.unreadDirectCount());
  }

  build() {
    Column() {
      NavBar({
        title: '消息',
        showBack: false,
      })

      if (this.loading) {
        LoadingView()
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 8 }) {
            // 互动通知聚合入口卡片：点入才展示通知列表
            ListItem() {
              this.NoticeEntry()
            }

            if (this.conversations.length > 0) {
              ListItem() {
                this.SectionLabel('私信')
              }
              ForEach(this.conversations, (item: DirectConversationItem) => {
                ListItem() {
                  ConversationItemView({
                    conversation: item,
                    unread: this.unreadOfConversation(item),
                    onOpen: (target: DirectConversationItem) => {
                      this.markConversationMessagesRead(target.id);
                      const param: ChatParam = { id: target.id, name: target.other.nickname };
                      this.navStack.pushPath({ name: 'Chat', param: param });
                    }
                  })
                }
              }, (item: DirectConversationItem) => `${item.id}`)
            }

            if (this.conversations.length === 0 && this.latestNotice.length === 0) {
              ListItem() {
                EmptyState({ title: '暂无消息', desc: '新的校园互动会出现在这里' })
              }
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 4, bottom: 12 })
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

  /** 互动通知入口卡片：铃铛图标 + 最新一条预览，未读数冒泡固定在卡片右侧。 */
  @Builder
  private NoticeEntry() {
    Row({ space: 12 }) {
      Stack() {
        Image($r('app.media.ic_bell'))
          .width(22)
          .height(22)
          .fillColor(AppColors.PRIMARY)
      }
      .width(46)
      .height(46)
      .borderRadius(23)
      .backgroundColor('#E8EFFC')

      Column({ space: 4 }) {
        Text('互动通知')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(this.latestNotice.length > 0 ? this.latestNotice : '点赞、评论等互动会出现在这里')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.noticeUnread > 0) {
        Text(this.noticeUnread > 99 ? '99+' : `${this.noticeUnread}`)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .height(16)
          .constraintSize({ minWidth: 16 })
          .padding({ left: 4, right: 4 })
          .backgroundColor(AppColors.DANGER)
          .borderRadius(8)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .onClick(() => {
      this.navStack.pushPath({ name: 'Notifications' });
    })
  }

  @Builder
  private SectionLabel(label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.TEXT_SECONDARY)
      .width('100%')
      .padding({ left: 4, top: 6, bottom: 2 })
  }
}
