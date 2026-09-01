import { hilog } from '@kit.PerformanceAnalysisKit';
import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { DirectMessage } from '../model/Types';
import { Session } from '../service/Session';
import { AppColors } from '../constants/AppConfig';
import { MessageBubble } from '../components/business/MessageBubble';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { NavBar } from '../components/common/NavBar';
import { AppState } from '../service/AppState';

const TAG = 'ChatPage';
const DOMAIN = 0x0001;

@Component
export struct ChatPage {
  @Consume('navStack') navStack: NavPathStack;
  @Prop conversationId: number = 0;
  @Prop otherName: string = '';
  @State messages: DirectMessage[] = [];
  @State loading: boolean = true;
  @State unlocked: boolean = false;
  @State draft: string = '';
  @State sending: boolean = false;
  /** 内置招呼用语：与 Web 端一致，取自服务端公共设置，失败时用兜底文案。 */
  @State greeting: string = '你好，我想和你聊聊';
  /** 前台消息变更信号：NotificationSync 轮询发现新私信时递增，驱动本页原地刷新。 */
  @StorageLink('xsnbb_message_revision') @Watch('onMessageRevisionChange') messageRevision: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    // 返回消息页、侧滑返回或切入其他页面时都强制补拉会话摘要。
    AppState.requestMessageRefresh();
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
      const settings = await Api.publicSettings();
      if (settings.greeting.length > 0) {
        this.greeting = settings.greeting;
      }
    } catch (e) {
      // 招呼用语拉取失败使用兜底文案
      hilog.error(DOMAIN, TAG, `load settings failed: ${(e as Error).message}`);
    }
    try {
      const resp = await Api.getDirectConversation(this.conversationId);
      this.messages = resp.conversation.messages;
      this.unlocked = resp.unlocked;
      this.scrollToBottom();
      // 进入会话即持久化已读：服务端把对方消息置为 read 并返回全量私信未读数，
      // 底栏冒泡与消息页未读随下次拉取保持清除，不再回弹。
      await Api.markDirectConversationRead(this.conversationId).catch((e: Error) => {
        hilog.error(DOMAIN, TAG, `markConversationRead failed: ${e.message}`);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, `load conversation failed: ${(e as Error).message}`);
    }
    this.loading = false;
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 80);
  }

  /**
   * 收到全局消息变更信号后原地刷新当前会话，不用返回消息页再进入。
   * 自己发送 / 已读协议也会触发该信号，刷新是幂等的；仅在有新的对方未读消息时
   * 才调用已读协议，避免「已读 → 发布信号 → 再刷新」的自我循环。
   */
  private onMessageRevisionChange(): void {
    if (!this.loading) {
      this.refreshConversation();
    }
  }

  private async refreshConversation(): Promise<void> {
    try {
      const previousLastId =
        this.messages.length > 0 ? this.messages[this.messages.length - 1].id : 0;
      const resp = await Api.getDirectConversation(this.conversationId);
      this.messages = resp.conversation.messages;
      this.unlocked = resp.unlocked;
      const currentLastId =
        this.messages.length > 0 ? this.messages[this.messages.length - 1].id : 0;
      if (currentLastId !== previousLastId) {
        this.scrollToBottom();
      }
      const myId = Session.currentAccount()?.id ?? -1;
      const hasUnreadIncoming = this.messages.some(
        (message: DirectMessage) => message.sender_id !== myId && message.status === 'delivered');
      if (hasUnreadIncoming) {
        // 正在会话内收到的对方消息立即已读：服务端持久化，底栏与消息页冒泡不回弹。
        await Api.markDirectConversationRead(this.conversationId).catch((e: Error) => {
          hilog.error(DOMAIN, TAG, `refresh markConversationRead failed: ${e.message}`);
        });
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `refresh conversation failed: ${(e as Error).message}`);
    }
  }

  private async send(text: string, system: boolean): Promise<void> {
    if (text.trim().length === 0 || this.sending) {
      return;
    }
    this.sending = true;
    try {
      const resp = await Api.sendDirectMessage(this.conversationId, text, system);
      this.messages = [...this.messages, resp.message];
      this.unlocked = resp.unlocked;
      this.draft = '';
      this.scrollToBottom();
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '发送失败，请稍后重试');
    } finally {
      this.sending = false;
    }
  }

  /** 回复内置招呼：双方各回一条后解锁自由聊天（与 Web 端握手流程一致）。 */
  private sendGreeting(): void {
    this.send(this.greeting, true);
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: this.otherName.length > 0 ? this.otherName : '私信',
          titleTag: this.unlocked ? '自由聊' : '',
          onBack: () => {
            this.navStack.pop();
          }
        })

        if (this.loading) {
          LoadingView()
        } else {
          List({ scroller: this.scroller }) {
            ForEach(this.messages, (message: DirectMessage) => {
              ListItem() {
                MessageBubble({
                  message: message,
                  isMine: message.sender_id === (Session.currentAccount()?.id ?? -1)
                })
              }
            }, (message: DirectMessage) => `${message.id}`)
            if (this.messages.length === 0) {
              ListItem() {
                EmptyState({ title: '还没有消息', desc: '发出第一句话吧' })
              }
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .layoutWeight(1)

          if (this.unlocked) {
            Row({ space: 10 }) {
              TextInput({ placeholder: '发送消息…', text: $$this.draft })
                .layoutWeight(1)
                .height(40)
                .backgroundColor(AppColors.CARD_BG)
                .borderRadius(20)
                .onSubmit(() => {
                  this.send(this.draft, false);
                })
              Button('发送')
                .height(40)
                .fontSize(14)
                .backgroundColor(this.draft.trim().length > 0 ? AppColors.PRIMARY : '#9AB6EA')
                .enabled(this.draft.trim().length > 0 && !this.sending)
                .onClick(() => {
                  this.send(this.draft, false);
                })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          } else {
            // 未解锁：与 Web 端一致的打招呼握手区，双方各回一条内置招呼后开放自由输入
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Text('🔒')
                  .fontSize(16)
                Column({ space: 4 }) {
                  Text('回复后解锁自由聊天')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY)
                  Text('首次联系双方各回复一条内置消息后，才可发送自由文字。')
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')

              Button(`回复"${this.greeting}"`)
                .width('100%')
                .height(40)
                .fontSize(14)
                .backgroundColor(AppColors.PRIMARY)
                .enabled(!this.sending)
                .onClick(() => {
                  this.sendGreeting();
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(AppColors.CARD_BG)
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
