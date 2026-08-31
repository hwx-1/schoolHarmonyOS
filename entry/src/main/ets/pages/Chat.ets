import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { DirectMessage } from '../model/Types';
import { Session } from '../service/Session';
import { AppColors } from '../constants/AppConfig';
import { MessageBubble } from '../components/business/MessageBubble';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';

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
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.load();
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
      const resp = await Api.getDirectConversation(this.conversationId);
      this.messages = resp.conversation.messages;
      this.unlocked = resp.unlocked;
      this.scrollToBottom();
    } catch {
    }
    this.loading = false;
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 80);
  }

  private async send(): Promise<void> {
    const text = this.draft.trim();
    if (text.length === 0 || this.sending) {
      return;
    }
    this.sending = true;
    try {
      const resp = await Api.sendDirectMessage(this.conversationId, text);
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

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('‹')
            .fontSize(26)
            .fontColor(AppColors.TEXT_PRIMARY)
            .padding({ right: 12 })
            .onClick(() => {
              this.navStack.pop();
            })
          Text(this.otherName.length > 0 ? this.otherName : '私信')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
          if (this.unlocked) {
            Text('自由聊')
              .fontSize(10)
              .fontColor('#0A8A4D')
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor('#140A8A4D')
              .borderRadius(4)
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 12, bottom: 8 })

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

          Row({ space: 10 }) {
            TextInput({ placeholder: '发送消息…', text: $$this.draft })
              .layoutWeight(1)
              .height(40)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(20)
              .onSubmit(() => {
                this.send();
              })
            Button('发送')
              .height(40)
              .fontSize(14)
              .backgroundColor(this.draft.trim().length > 0 ? AppColors.PRIMARY : '#9AB6EA')
              .enabled(this.draft.trim().length > 0 && !this.sending)
              .onClick(() => {
                this.send();
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
