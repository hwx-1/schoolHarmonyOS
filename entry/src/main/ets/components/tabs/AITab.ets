import { Api } from '../../service/Api';
import { ApiError } from '../../service/Http';
import { AIChatParam, AIConversation } from '../../model/Types';
import { TimeUtil } from '../../utils/TimeUtil';
import { AppColors } from '../../constants/AppConfig';
import { LoadingView } from '../common/LoadingView';
import { EmptyState } from '../common/EmptyState';
import { NavBar } from '../common/NavBar';

/** AI 问答页：会话列表 + 剩余次数 + 新建会话。 */
@Component
export struct AITab {
  @Consume('navStack') navStack: NavPathStack;
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State conversations: AIConversation[] = [];
  @State remaining: number = 0;

  aboutToAppear(): void {
    this.loadAll();
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
      const resp = await Api.aiConversations();
      this.conversations = resp.items;
      this.remaining = resp.remaining;
    } catch {
    }
    this.loading = false;
    this.refreshing = false;
  }

  private async createConversation(): Promise<void> {
    try {
      const resp = await Api.createAIConversation('', '');
      const param: AIChatParam = { id: resp.conversation.id, title: resp.conversation.title };
      this.navStack.pushPath({ name: 'AIChat', param: param });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '创建会话失败');
    }
  }

  build() {
    Column() {
      NavBar({
        title: 'AI 校园助手',
        subtitle: `今日剩余 ${this.remaining} 次提问`,
        onBack: () => {
          this.navStack.pop();
        },
        rightButtonText: '+ 新会话',
        onRightButton: () => {
          this.createConversation();
        }
      })

      if (this.loading) {
        LoadingView()
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 10 }) {
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
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(14)
                .backgroundColor(AppColors.CARD_BG)
                .borderRadius(12)
                .alignItems(HorizontalAlign.Start)
                .onClick(() => {
                  const param: AIChatParam = { id: item.id, title: item.title };
                  this.navStack.pushPath({ name: 'AIChat', param: param });
                })
              }
            // 键值带上标题与消息数：否则 AI 会话条目复用旧数据，消息条数不刷新。
            }, (item: AIConversation) => `${item.id}:${item.title}:${item.messages.length}`)

            if (this.conversations.length === 0) {
              ListItem() {
                EmptyState({
                  title: '还没有 AI 会话',
                  desc: '试试问「图书馆几点关门」',
                  actionText: '开始提问',
                  onAction: () => {
                    this.createConversation();
                  }
                })
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
}
