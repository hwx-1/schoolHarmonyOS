import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { AIMessage, AIConversation, AIChatParam } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { NavBar } from '../components/common/NavBar';

/** AI 对话页：仿 DeepSeek 移动端布局 —— 白底、AI 消息通栏无气泡、用户消息右侧浅灰气泡、
 *  底部圆角输入卡片内嵌「深度思考 / 联网搜索」开关与圆形发送按钮。 */
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
  @State deepThink: boolean = false;
  @State webSearch: boolean = false;
  private scroller: Scroller = new Scroller();
  private readonly examples: string[] = ['图书馆几点关门？', '教务处电话是多少？', '奖学金怎么申请？'];

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

  private async ask(text?: string): Promise<void> {
    const question = (text ?? this.draft).trim();
    if (question.length === 0 || this.asking) {
      return;
    }
    this.asking = true;
    this.draft = '';
    try {
      const resp = await Api.askAI(this.conversationId, question, '');
      this.messages = [...this.messages, resp.user_message, resp.answer];
      this.remaining = resp.remaining;
      this.scrollToBottom();
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '提问失败，请稍后重试');
    } finally {
      this.asking = false;
    }
  }

  private async newConversation(): Promise<void> {
    try {
      const resp = await Api.createAIConversation('', '');
      const param: AIChatParam = { id: resp.conversation.id, title: resp.conversation.title };
      this.navStack.replacePath({ name: 'AIChat', param: param });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '创建会话失败');
    }
  }

  /** 开关胶囊：深度思考 / 联网搜索 */
  @Builder
  private toggleChip(label: string, active: boolean, onTap: () => void): void {
    Text(label)
      .fontSize(12)
      .fontColor(active ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(active ? '#E8EFFC' : Color.Transparent)
      .borderRadius(14)
      .border({ width: 1, color: active ? AppColors.PRIMARY : AppColors.DIVIDER })
      .onClick(onTap)
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部栏：返回 / 居中会话标题 / 新建对话（对应 DeepSeek 的菜单 / 标题 / 新会话）
        NavBar({
          title: this.title,
          subtitle: this.remaining >= 0 ? `今日剩余 ${this.remaining} 次` : '',
          onBack: () => {
            this.navStack.pop();
          },
          rightText: '✎',
          rightFontSize: 20,
          rightColor: AppColors.TEXT_PRIMARY,
          onRight: () => {
            this.newConversation();
          }
        })

        // 消息区
        List({ scroller: this.scroller }) {
          if (this.messages.length === 0) {
            // 空会话欢迎页：居中 Logo + 问候语 + 示例问题（DeepSeek 开屏样式）
            ListItem() {
              Column({ space: 16 }) {
                Column({ space: 10 }) {
                  Text('✦')
                    .fontSize(34)
                    .fontColor(AppColors.PRIMARY)
                  Text('有什么可以帮你？')
                    .fontSize(22)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY)
                  Text('我是 AI 校园助手，校内服务、办事流程都可以问我')
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Center)

                Column({ space: 10 }) {
                  ForEach(this.examples, (example: string) => {
                    Text(example)
                      .fontSize(14)
                      .fontColor(AppColors.TEXT_PRIMARY)
                      .width('100%')
                      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                      .backgroundColor(AppColors.PAGE_BG)
                      .borderRadius(16)
                      .onClick(() => {
                        this.ask(example);
                      })
                  }, (example: string) => example)
                }
                .width('100%')
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 64 })
            }
          }

          ForEach(this.messages, (message: AIMessage) => {
            ListItem() {
              if (message.role === 'user') {
                // 用户消息：右侧浅灰圆角气泡（DeepSeek 风格，深色文字）
                Row() {
                  Text(message.text)
                    .fontSize(15)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                    .backgroundColor('#EFF3FA')
                    .borderRadius(18)
                    .constraintSize({ maxWidth: '78%' })
                }
                .width('100%')
                .justifyContent(FlexAlign.End)
              } else {
                // AI 消息：通栏无气泡，底部小字标注来源与甄别提示
                Column({ space: 6 }) {
                  Text(message.text)
                    .fontSize(16)
                    .lineHeight(24)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .width('100%')
                  Row({ space: 12 }) {
                    if (message.source && message.source.length > 0) {
                      Text(message.source)
                        .fontSize(11)
                        .fontColor(AppColors.TEXT_SECONDARY)
                    }
                    Text('内容由 AI 生成，请仔细甄别')
                      .fontSize(11)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }
            .width('100%')
            .margin({ top: 8, bottom: 8 })
          }, (message: AIMessage) => `${message.id}`)

          if (this.asking) {
            ListItem() {
              Row({ space: 8 }) {
                LoadingProgress()
                  .width(18)
                  .height(18)
                  .color(AppColors.PRIMARY)
                Text('正在思考…')
                  .fontSize(14)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .padding({ top: 8, bottom: 8 })
            }
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .layoutWeight(1)

        // 底部输入卡片：多行输入框 + 开关胶囊 + 圆形发送键（DeepSeek 底部工具区）
        Column({ space: 4 }) {
          TextArea({ placeholder: '有问题，尽管问', text: $$this.draft })
            .width('100%')
            .constraintSize({ minHeight: 44, maxHeight: 120 })
            .fontSize(15)
            .fontColor(AppColors.TEXT_PRIMARY)
            .placeholderColor(AppColors.TEXT_SECONDARY)
            .backgroundColor(Color.Transparent)
            .padding({ left: 4, right: 4, top: 6, bottom: 6 })

          Row() {
            this.toggleChip('深度思考', this.deepThink, () => {
              this.deepThink = !this.deepThink;
            })
            Blank().width(8)
            this.toggleChip('联网搜索', this.webSearch, () => {
              this.webSearch = !this.webSearch;
            })
            Blank().layoutWeight(1)
            // 圆形发送键：有内容时点亮为主题蓝
            Text('↑')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width(32)
              .height(32)
              .borderRadius(16)
              .backgroundColor(this.draft.trim().length > 0 ? AppColors.PRIMARY : '#C7CEDA')
              .enabled(this.draft.trim().length > 0 && !this.asking)
              .onClick(() => {
                this.ask();
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 6, bottom: 10 })
        .margin({ left: 12, right: 12, bottom: 10 })
        .backgroundColor(Color.White)
        .borderRadius(24)
        .border({ width: 1, color: AppColors.DIVIDER })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
  }
}
