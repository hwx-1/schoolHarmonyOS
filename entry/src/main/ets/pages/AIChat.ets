import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { AIMessage, AIConversation } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';

@Component
export struct AIChatPage {
  @Consume('navStack') navStack: NavPathStack;
  @Prop conversationId: number = 0;
  @Prop conversationTitle: string = '';
  @State messages: AIMessage[] = [];
  @State remaining: number = -1;
  @State draft: string = '';
  @State asking: boolean = false;
  @State title: string = 'AI 校园助手';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    if (this.conversationTitle.length > 0) {
      this.title = this.conversationTitle;
    }
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
      const resp = await Api.aiConversations();
      this.remaining = resp.remaining;
      const found = resp.items.find((item: AIConversation) => item.id === this.conversationId);
      if (found) {
        this.messages = found.messages;
        if (found.title.length > 0) {
          this.title = found.title;
        }
      }
    } catch {
    }
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 80);
  }

  private async ask(): Promise<void> {
    const text = this.draft.trim();
    if (text.length === 0 || this.asking) {
      return;
    }
    this.asking = true;
    this.draft = '';
    try {
      const resp = await Api.askAI(this.conversationId, text, '');
      this.messages = [...this.messages, resp.user_message, resp.answer];
      this.remaining = resp.remaining;
      this.scrollToBottom();
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '提问失败，请稍后重试');
    } finally {
      this.asking = false;
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
          Column({ space: 2 }) {
            Text(this.title)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
            if (this.remaining >= 0) {
              Text(`今日剩余 ${this.remaining} 次`)
                .fontSize(11)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 12, bottom: 8 })

        List({ scroller: this.scroller }) {
          ForEach(this.messages, (message: AIMessage) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(message.text)
                    .fontSize(15)
                    .fontColor(message.role === 'user' ? Color.White : AppColors.TEXT_PRIMARY)
                  if (message.role !== 'user' && message.source && message.source.length > 0) {
                    Text(`来源：${message.source}`)
                      .fontSize(10)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(message.role === 'user' ? AppColors.PRIMARY : AppColors.CARD_BG)
                .borderRadius(14)
                .constraintSize({ maxWidth: '80%' })
              }
              .width('100%')
              .justifyContent(message.role === 'user' ? FlexAlign.End : FlexAlign.Start)
              .margin({ top: 6, bottom: 6 })
            }
          }, (message: AIMessage) => `${message.id}`)

          if (this.messages.length === 0) {
            ListItem() {
              EmptyState({ title: '向 AI 校园助手提问吧', desc: '例如：图书馆几点关门？' })
            }
          }
          if (this.asking) {
            ListItem() {
              Row({ space: 8 }) {
                LoadingProgress()
                  .width(18)
                  .height(18)
                  .color(AppColors.PRIMARY)
                Text('正在思考…')
                  .fontSize(13)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .padding(10)
            }
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .layoutWeight(1)

        Row({ space: 10 }) {
          TextInput({ placeholder: '输入你的问题…', text: $$this.draft })
            .layoutWeight(1)
            .height(40)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(20)
            .onSubmit(() => {
              this.ask();
            })
          Button(this.asking ? '思考中' : '提问')
            .height(40)
            .fontSize(14)
            .backgroundColor(this.draft.trim().length > 0 ? AppColors.PRIMARY : '#9AB6EA')
            .enabled(this.draft.trim().length > 0 && !this.asking)
            .onClick(() => {
              this.ask();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
