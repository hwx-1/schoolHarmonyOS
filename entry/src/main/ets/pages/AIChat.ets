import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { AIMessage, AIConversation, AIChatParam, AIStreamEvent } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { TimeUtil } from '../utils/TimeUtil';
import { NavBar } from '../components/common/NavBar';
import { EmptyState } from '../components/common/EmptyState';
import { LoadingView } from '../components/common/LoadingView';
import { AIAnswerBubble } from '../components/business/AIAnswerBubble';

/**
 * AI 对话页（对齐安卓端 AIChatScreen，仿 DeepSeek 移动端布局）：
 * 进入即展开新对话，右上角提供「对话记录」与「新对话」两个入口，历史会话以半模态弹层展示。
 * 发送后立即展示用户消息，AI 回复走 SSE 流式渲染，思考过程可收起/展开（默认收起）。
 * conversationId 为 0 时自动创建新会话并替换为带 id 的路由；否则加载对应会话。
 */
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
  @State conversations: AIConversation[] = [];
  @State showHistory: boolean = false;
  @State deepThink: boolean = false;
  @State webSearch: boolean = false;
  @State streamReasoning: string = '';
  @State streamText: string = '';
  @State feedbackPendingId: number = 0;
  private pendingUserTempId: number = 0;
  private scrollScheduled: boolean = false;
  private scroller: Scroller = new Scroller();
  private readonly examples: string[] = ['图书馆几点关门？', '教务处电话是多少？', '奖学金怎么申请？'];

  aboutToAppear(): void {
    if (this.conversationTitle.length > 0) {
      this.title = this.conversationTitle;
    }
    if (this.conversationId === 0) {
      this.createAndReplace(true);
      return;
    }
    this.loadCurrent();
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async loadConversations(): Promise<void> {
    try {
      const resp = await Api.aiConversations();
      this.remaining = resp.remaining;
      // 历史记录按时间倒序：最新在上，越久越靠下
      this.conversations = [...resp.items].sort((a: AIConversation, b: AIConversation) =>
        b.created_at.localeCompare(a.created_at));
    } catch {
      // 历史列表加载失败不打断对话
    }
  }

  private async loadCurrent(): Promise<void> {
    await this.loadConversations();
    const found = this.conversations.find((item: AIConversation) => item.id === this.conversationId);
    if (found) {
      this.messages = found.messages;
      if (found.title.length > 0) {
        this.title = found.title;
      }
      this.scrollToBottom();
    }
  }

  /** 创建新会话并把当前页替换为带 id 的对话页；popOnFail 用于直接进入 AI 页时建会话失败的退出。 */
  private async createAndReplace(popOnFail: boolean): Promise<void> {
    try {
      const resp = await Api.createAIConversation('', '');
      const param: AIChatParam = { id: resp.conversation.id, title: resp.conversation.title };
      this.navStack.replacePath({ name: 'AIChat', param: param });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '创建会话失败');
      if (popOnFail) {
        this.navStack.pop();
      }
    }
  }

  private newConversation(): void {
    if (this.asking) {
      return;
    }
    this.showHistory = false;
    this.createAndReplace(false);
  }

  private openConversation(item: AIConversation): void {
    this.showHistory = false;
    if (item.id === this.conversationId) {
      return;
    }
    const param: AIChatParam = { id: item.id, title: item.title };
    this.navStack.replacePath({ name: 'AIChat', param: param });
  }

  private showHistoryPanel(): void {
    this.showHistory = true;
    this.loadConversations();
  }

  private confirmDelete(item: AIConversation): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '删除 AI 会话',
      message: '删除后各设备将同步移除，且无法恢复。',
      buttons: [
        { text: '取消', color: AppColors.TEXT_SECONDARY },
        { text: '删除', color: AppColors.DANGER },
      ]
    }).then((resp) => {
      if (resp.index === 1) {
        Api.deleteAIConversation(item.id).then(() => {
          this.conversations = this.conversations.filter(
            (conversation: AIConversation) => conversation.id !== item.id);
          this.toast('会话已删除');
          if (item.id === this.conversationId) {
            // 删掉的是当前会话：直接开一个新会话接着聊
            this.showHistory = false;
            this.createAndReplace(true);
          }
        }).catch((err: Error) => this.toast(err.message || '删除失败'));
      }
    }).catch(() => {
      // 用户取消或系统对话框异常时不执行删除。
    });
  }

  /** 流式增量到达频繁，合并 60ms 内的滚动请求。 */
  private scrollToBottom(): void {
    if (this.scrollScheduled) {
      return;
    }
    this.scrollScheduled = true;
    setTimeout(() => {
      this.scrollScheduled = false;
      this.scroller.scrollEdge(Edge.Bottom);
    }, 60);
  }

  private resetStream(): void {
    this.asking = false;
    this.streamReasoning = '';
    this.streamText = '';
  }

  private handleStreamEvent(event: AIStreamEvent, question: string, tempId: number): void {
    if (event.type === 'thinking') {
      this.streamReasoning += event.delta ?? '';
      this.scrollToBottom();
    } else if (event.type === 'text') {
      this.streamText += event.delta ?? '';
      this.scrollToBottom();
    } else if (event.type === 'done') {
      const base = this.messages.filter((item: AIMessage) => item.id !== this.pendingUserTempId);
      // 服务端未随 done 返回持久化消息时，用本地累积的流式内容兜底
      const fallbackUser: AIMessage = { id: tempId, role: 'user', text: question, created_at: '' };
      const fallbackAnswer: AIMessage = {
        id: tempId - 1,
        role: 'assistant',
        text: this.streamText,
        reasoning: this.streamReasoning.length > 0 ? this.streamReasoning : undefined,
        created_at: '',
      };
      const user: AIMessage = event.user_message ?? fallbackUser;
      const answer: AIMessage = event.answer ?? fallbackAnswer;
      this.messages = [...base, user, answer];
      if (event.remaining !== undefined) {
        this.remaining = event.remaining;
      }
      this.resetStream();
      this.scrollToBottom();
    } else if (event.type === 'error') {
      this.toast(event.message ?? '回答中断，本次不扣额度');
      this.resetStream();
    }
  }

  private async ask(text?: string): Promise<void> {
    const question = (text ?? this.draft).trim();
    if (question.length === 0 || this.asking || this.conversationId === 0) {
      return;
    }
    this.asking = true;
    this.draft = '';
    // 负数临时 id，避免与服务端 id 冲突；立即展示用户消息，不等 AI 回答
    const tempId = -Date.now();
    this.pendingUserTempId = tempId;
    const pendingUser: AIMessage = { id: tempId, role: 'user', text: question, created_at: '' };
    this.messages = [...this.messages, pendingUser];
    this.streamReasoning = '';
    this.streamText = '';
    this.scrollToBottom();
    try {
      await Api.askAIStream(this.conversationId, question, '', (event: AIStreamEvent) => {
        this.handleStreamEvent(event, question, tempId);
      });
      if (this.asking) {
        // 流正常结束但没有收到 done：保留已生成的内容
        const doneEvent: AIStreamEvent = { type: 'done' };
        this.handleStreamEvent(doneEvent, question, tempId);
      }
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '提问失败，请稍后重试');
      this.resetStream();
    }
  }

  private async sendFeedback(messageId: number, satisfied: boolean): Promise<void> {
    if (this.feedbackPendingId !== 0) {
      return;
    }
    this.feedbackPendingId = messageId;
    try {
      const resp = await Api.aiFeedback(this.conversationId, messageId, satisfied);
      this.remaining = resp.remaining;
      this.messages = this.messages.map((message: AIMessage) => {
        if (message.id !== messageId) {
          return message;
        }
        if (resp.message) {
          return resp.message;
        }
        const updated: AIMessage = {
          id: message.id,
          role: message.role,
          text: message.text,
          reasoning: message.reasoning,
          model: message.model,
          source: message.source,
          needs_feedback: false,
          feedback: satisfied ? 'yes' : 'no',
          created_at: message.created_at,
        };
        return updated;
      });
      if (resp.answer) {
        this.messages = [...this.messages, resp.answer];
        this.scrollToBottom();
      }
      this.toast(satisfied ? '感谢反馈' : '已为你重新检索');
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '反馈失败，请稍后重试');
    } finally {
      this.feedbackPendingId = 0;
    }
  }

  // 键值带上反馈状态与正文长度：否则反馈后条目复用旧数据，按钮不消失。
  private messageRenderKey(message: AIMessage): string {
    return `${message.id}_${message.needs_feedback ? 1 : 0}_${message.feedback ?? ''}_${message.text.length}`;
  }

  /** 输入区开关胶囊。必须以单个对象字面量传参：按引用传递，选中态变化才能驱动刷新。 */
  @Builder
  ToggleChip(params: ToggleChipParams) {
    Text(params.label)
      .fontSize(12)
      .fontColor(params.active ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(params.active ? '#142E6BE6' : Color.Transparent)
      .borderRadius(14)
      .border({ width: 1, color: params.active ? AppColors.PRIMARY : AppColors.DIVIDER })
      .onClick(() => params.onTap())
  }

  @Builder
  HistorySheet() {
    Column() {
      if (this.conversations.length === 0) {
        EmptyState({ title: '还没有 AI 会话', desc: '开始提问后会自动保存' })
          .margin({ top: 40 })
      } else {
        List({ space: 8 }) {
          ForEach(this.conversations, (item: AIConversation) => {
            ListItem() {
              Column({ space: 4 }) {
                Text(item.title.length > 0 ? item.title : '未命名会话')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row() {
                  Text(`${item.messages.length} 条消息`)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                  Blank()
                  Text(TimeUtil.format(item.created_at))
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_SECONDARY)
                  Text('删除')
                    .fontSize(11)
                    .fontColor(AppColors.DANGER)
                    .margin({ left: 12 })
                    .onClick(() => this.confirmDelete(item))
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(item.id === this.conversationId ? '#142E6BE6' : AppColors.CARD_BG)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => this.openConversation(item))
            }
          }, (item: AIConversation) => `${item.id}:${item.title}:${item.messages.length}:${item.id === this.conversationId ? 1 : 0}`)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部栏：返回 / 居中会话标题 + 剩余次数 / 右上角「对话记录」「新对话」
        NavBar({
          title: this.title,
          subtitle: this.remaining >= 0 ? `今日剩余 ${this.remaining} 次` : '',
          onBack: () => {
            this.navStack.pop();
          },
          rightSecondaryText: '对话记录',
          onRightSecondary: () => {
            this.showHistoryPanel();
          },
          rightText: '新对话',
          rightFontSize: 13,
          onRight: () => {
            this.newConversation();
          }
        })

        if (this.conversationId === 0) {
          LoadingView()
        } else {
          // 消息区
          List({ scroller: this.scroller }) {
            if (this.messages.length === 0 && !this.asking) {
              // 空会话欢迎页：居中 Logo + 问候语 + 示例问题
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
                  // 用户消息：右侧浅灰圆角气泡
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
                  AIAnswerBubble({
                    reasoning: message.reasoning ?? '',
                    text: message.text,
                    source: message.source ?? '',
                    needsFeedback: message.needs_feedback ?? false,
                    feedback: message.feedback ?? '',
                    feedbackLocked: this.feedbackPendingId !== 0,
                    feedbackBusy: this.feedbackPendingId === message.id,
                    onFeedback: (satisfied: boolean) => {
                      this.sendFeedback(message.id, satisfied);
                    }
                  })
                }
              }
              .width('100%')
              .margin({ top: 6, bottom: 6 })
            }, (message: AIMessage) => this.messageRenderKey(message))

            if (this.asking) {
              // 流式生成中的临时气泡：done 后由持久化消息替换
              ListItem() {
                AIAnswerBubble({
                  reasoning: this.streamReasoning,
                  text: this.streamText,
                  showSpinner: this.streamReasoning.length === 0 && this.streamText.length === 0
                })
              }
              .width('100%')
              .margin({ top: 6, bottom: 6 })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .layoutWeight(1)
        }

        // 底部输入卡片：多行输入框 + 开关胶囊 + 圆形发送键
        Column({ space: 4 }) {
          TextArea({ placeholder: '有问题，尽管问', text: $$this.draft })
            .width('100%')
            .constraintSize({ minHeight: 44, maxHeight: 120 })
            .fontSize(15)
            .fontColor(AppColors.TEXT_PRIMARY)
            .placeholderColor(AppColors.TEXT_SECONDARY)
            .backgroundColor(Color.Transparent)
            .padding({ left: 4, right: 4, top: 6, bottom: 6 })

          Row({ space: 8 }) {
            this.ToggleChip({
              label: '深度思考', active: this.deepThink, onTap: () => {
                this.deepThink = !this.deepThink;
              }
            })
            this.ToggleChip({
              label: '联网搜索', active: this.webSearch, onTap: () => {
                this.webSearch = !this.webSearch;
              }
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
      .bindSheet($$this.showHistory, this.HistorySheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: true,
        backgroundColor: AppColors.PAGE_BG,
        title: { title: '对话记录' },
        onDisappear: () => {
          this.showHistory = false;
        }
      })
    }
    .hideTitleBar(true)
  }
}

/** 输入区开关胶囊参数。 */
interface ToggleChipParams {
  label: string;
  active: boolean;
  onTap: () => void;
}
