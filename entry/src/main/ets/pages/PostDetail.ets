import { Api } from '../service/Api';
import { ApiError, absoluteMediaUrl } from '../service/Http';
import { ChatParam, CommentItem, Post, SearchParam } from '../model/Types';
import { Session } from '../service/Session';
import { TimeUtil } from '../utils/TimeUtil';
import { AppColors } from '../constants/AppConfig';
import { AvatarView } from '../components/common/AvatarView';
import { BadgeView } from '../components/common/BadgeView';
import { TagChip } from '../components/common/TagChip';
import { CommentItemView } from '../components/business/CommentItemView';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { NavBar } from '../components/common/NavBar';

@Component
export struct PostDetailPage {
  @Consume('navStack') navStack: NavPathStack;
  @StorageLink('xsnbb_post_revision') @Watch('onPostRevisionChange') postRevision: number = 0;
  @Prop postId: number = 0;
  @State post: Post | null = null;
  @State comments: CommentItem[] = [];
  @State loading: boolean = true;
  @State loadError: string = '';
  @State commentText: string = '';
  @State sending: boolean = false;
  @State startingChat: boolean = false;
  /** 回复目标：非空时输入框处于「回复 @昵称」模式（抖音式两级评论）。 */
  @State replyTo: CommentItem | null = null;
  /** 已展开全部回复的主评论 id 列表：默认只展示前 2 条回复。 */
  @State expandedRoots: number[] = [];

  aboutToAppear(): void {
    this.loadAll();
  }

  private onPostRevisionChange(): void {
    if (!this.loading) {
      this.loadPost();
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
    this.loadError = '';
    const loaded = await this.loadPost();
    if (!loaded) {
      this.loading = false;
      return;
    }
    try {
      const commentResp = await Api.listComments(this.postId);
      this.comments = commentResp.items;
    } catch {
    }
    this.loading = false;
  }

  private async loadPost(): Promise<boolean> {
    try {
      const resp = await Api.getPost(this.postId);
      this.post = resp.post;
      return true;
    } catch (err) {
      this.loadError = err instanceof ApiError ? err.message : '帖子加载失败';
      return false;
    }
  }

  /** 从帖子作者发起私信：建立（或复用）会话后进入聊天页，与 Web 端用户主页行为一致。 */
  private async startChat(): Promise<void> {
    if (!this.post || this.startingChat) {
      return;
    }
    this.startingChat = true;
    try {
      const resp = await Api.startDirectConversation(this.post.author.id);
      const param: ChatParam = { id: resp.item.id, name: this.post.author.nickname };
      this.navStack.pushPath({ name: 'Chat', param: param });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '发起私信失败，请稍后重试');
    } finally {
      this.startingChat = false;
    }
  }

  private async handleLike(): Promise<void> {
    if (!this.post) {
      return;
    }
    try {
      const resp = await Api.likePost(this.post.id);
      this.post = resp.post;
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '操作失败');
    }
  }

  private async handleBookmark(): Promise<void> {
    if (!this.post) {
      return;
    }
    try {
      const resp = await Api.bookmarkPost(this.post.id);
      this.post = resp.post;
      this.toast(resp.post.bookmarked ? '已收藏' : '已取消收藏');
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '操作失败');
    }
  }

  private async sendComment(): Promise<void> {
    const text = this.commentText.trim();
    if (text.length === 0 || this.sending) {
      return;
    }
    this.sending = true;
    try {
      const resp = await Api.createComment(this.postId, text, this.replyTo?.id);
      if (!resp.moderation.pass) {
        this.toast(resp.message || '评论未通过内容审核');
      } else {
        this.comments = [...this.comments, resp.comment];
        this.commentText = '';
        this.replyTo = null;
        // 发送成功后收起输入法键盘（清除输入框焦点）。
        this.getUIContext().getFocusController().clearFocus();
        if (this.post) {
          const current: Post = this.post;
          this.post = {
            id: current.id,
            author: current.author,
            text: current.text,
            images: current.images,
            tags: current.tags,
            status: current.status,
            pinned: current.pinned,
            likes: current.likes,
            comments: current.comments + 1,
            bookmarks: current.bookmarks,
            liked: current.liked,
            bookmarked: current.bookmarked,
            created_at: current.created_at,
            updated_at: current.updated_at,
          };
        }
      }
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '评论失败，请稍后重试');
    } finally {
      this.sending = false;
    }
  }

  // ---- 抖音式两级评论：主评论 + 归属于根评论的扁平回复列表 ----

  private commentById(id: number): CommentItem | null {
    const found = this.comments.find((item: CommentItem) => item.id === id);
    return found ?? null;
  }

  /** 根评论 id：沿 parent_id 上溯到没有父级的评论。 */
  private rootIdOf(comment: CommentItem): number {
    let current: CommentItem = comment;
    const seen: number[] = [];
    while (current.parent_id !== undefined && current.parent_id > 0 && seen.indexOf(current.id) < 0) {
      seen.push(current.id);
      const parent = this.commentById(current.parent_id);
      if (!parent) {
        break;
      }
      current = parent;
    }
    return current.id;
  }

  /** 主评论列表（无 parent_id），按时间正序。 */
  private rootComments(): CommentItem[] {
    return this.comments.filter((item: CommentItem) =>
      item.parent_id === undefined || item.parent_id === 0 || this.commentById(item.parent_id) === null);
  }

  /** 归属于某根评论的全部回复（扁平，含回复的回复），按时间正序。 */
  private repliesOf(rootId: number): CommentItem[] {
    return this.comments.filter((item: CommentItem) =>
      !(item.parent_id === undefined || item.parent_id === 0) && this.rootIdOf(item) === rootId);
  }

  /** 默认只展示前 2 条回复，展开后显示全部。 */
  private visibleReplies(rootId: number): CommentItem[] {
    const replies = this.repliesOf(rootId);
    if (this.expandedRoots.indexOf(rootId) >= 0) {
      return replies;
    }
    return replies.slice(0, 2);
  }

  /** 「回复 @对方」前缀：仅回复另一条回复时展示，直接回复主评论不展示。 */
  private replyTargetName(comment: CommentItem): string {
    if (comment.parent_id === undefined || comment.parent_id === 0) {
      return '';
    }
    if (comment.parent_id === this.rootIdOf(comment)) {
      return '';
    }
    const parent = this.commentById(comment.parent_id);
    if (!parent || parent.deleted) {
      return '';
    }
    return `@${parent.author.nickname}`;
  }

  private startReply(comment: CommentItem): void {
    this.replyTo = comment;
    // 进入回复模式后自动聚焦输入框并唤起输入法键盘。
    // 延迟一帧等输入框 placeholder 刷新后再请求焦点，避免焦点被刷新打断。
    setTimeout(() => {
      this.getUIContext().getFocusController().requestFocus('commentInput');
    }, 50);
  }

  private cancelReply(): void {
    this.replyTo = null;
    // 取消回复时同样收起键盘。
    this.getUIContext().getFocusController().clearFocus();
  }

  private toggleReplies(rootId: number): void {
    if (this.expandedRoots.indexOf(rootId) >= 0) {
      this.expandedRoots = this.expandedRoots.filter((id: number) => id !== rootId);
    } else {
      this.expandedRoots = [...this.expandedRoots, rootId];
    }
  }

  private hasReplyTarget(): boolean {
    return this.replyTo !== null;
  }

  private replyToNickname(): string {
    return this.replyTo ? this.replyTo.author.nickname : '';
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部栏
        NavBar({
          title: '帖子详情',
          onBack: () => {
            this.navStack.pop();
          }
        })

        if (this.loading) {
          LoadingView()
        } else if (this.loadError.length > 0 || !this.post) {
          EmptyState({
            title: '加载失败',
            desc: this.loadError,
            actionText: '重试',
            onAction: () => this.loadAll()
          })
        } else {
          List({ space: 12 }) {
            ListItem() {
              // 正文区
              Column({ space: 12 }) {
                Row({ space: 10 }) {
                  AvatarView({
                    avatar: this.post.author.avatar,
                    nickname: this.post.author.nickname,
                    diameter: 44
                  })
                  Column({ space: 2 }) {
                    Row({ space: 6 }) {
                      Text(this.post.author.nickname)
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppColors.TEXT_PRIMARY)
                      if (this.post.author.verified) {
                        BadgeView({ badge: this.post.author.badge ?? 'org' })
                      }
                    }
                    Text(TimeUtil.format(this.post.created_at))
                      .fontSize(12)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  if (this.post.author.id !== (Session.currentAccount()?.id ?? -1)) {
                    Button('私信')
                      .height(30)
                      .fontSize(13)
                      .backgroundColor(AppColors.PRIMARY)
                      .enabled(!this.startingChat)
                      .onClick(() => {
                        this.startChat();
                      })
                  }
                }

                Text(this.post.text)
                  .fontSize(16)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .width('100%')

                if (this.post.images && this.post.images.length > 0) {
                  Column({ space: 8 }) {
                    ForEach(this.post.images, (path: string) => {
                      Image(absoluteMediaUrl(path))
                        .width('100%')
                        .objectFit(ImageFit.Cover)
                        .borderRadius(10)
                    }, (path: string) => path)
                  }
                  .width('100%')
                }

                if (this.post.tags && this.post.tags.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.post.tags, (tag: string) => {
                      TagChip({
                        text: tag,
                        onTap: (target: string) => {
                          const param: SearchParam = { keyword: target };
                          this.navStack.pushPath({ name: 'Search', param: param });
                        }
                      })
                        .margin({ right: 8, bottom: 4 })
                    }, (tag: string) => tag)
                  }
                  .width('100%')
                }

                Row() {
                  Row({ space: 4 }) {
                    Image($r('app.media.ic_heart'))
                      .width(16)
                      .height(16)
                      .fillColor(this.post.liked ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
                    Text(`${this.post.likes}`)
                      .fontSize(13)
                      .fontColor(this.post.liked ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
                  }
                  .padding(8)
                  .onClick(() => this.handleLike())

                  Row({ space: 4 }) {
                    Image($r('app.media.ic_star'))
                      .width(16)
                      .height(16)
                      .fillColor(this.post.bookmarked ? AppColors.ORANGE : AppColors.TEXT_SECONDARY)
                    Text(`${this.post.bookmarks}`)
                      .fontSize(13)
                      .fontColor(this.post.bookmarked ? AppColors.ORANGE : AppColors.TEXT_SECONDARY)
                  }
                  .padding(8)
                  .onClick(() => this.handleBookmark())
                }
                .width('100%')
                .justifyContent(FlexAlign.End)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }

            ListItem() {
              // 评论区（抖音式两级：主评论 + 可折叠的扁平回复）
              Column({ space: 4 }) {
                Text(`评论 ${this.comments.length}`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
                if (this.comments.length === 0) {
                  EmptyState({ title: '还没有评论', desc: '抢个沙发吧' })
                } else {
                  ForEach(this.rootComments(), (root: CommentItem) => {
                    Column() {
                      CommentItemView({
                        comment: root,
                        onReply: (target: CommentItem) => this.startReply(target)
                      })
                      if (this.repliesOf(root.id).length > 0) {
                        Column() {
                          ForEach(this.visibleReplies(root.id), (reply: CommentItem) => {
                            CommentItemView({
                              comment: reply,
                              isReply: true,
                              replyToName: this.replyTargetName(reply),
                              onReply: (target: CommentItem) => this.startReply(target)
                            })
                          }, (reply: CommentItem) => `${reply.id}:${reply.deleted ? 1 : 0}`)
                          if (this.repliesOf(root.id).length > 2) {
                            Text(this.expandedRoots.indexOf(root.id) >= 0
                              ? '收起回复 ∧'
                              : `展开 ${this.repliesOf(root.id).length - 2} 条回复 ⌄`)
                              .fontSize(12)
                              .fontColor(AppColors.TEXT_SECONDARY)
                              .padding({ top: 2, bottom: 6 })
                              .onClick(() => {
                                this.toggleReplies(root.id);
                              })
                          }
                        }
                        .width('100%')
                        .padding({ left: 42 })
                        .alignItems(HorizontalAlign.Start)
                      }
                    }
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)
                  // 键值带上删除态与回复数：否则审核删除或新回复到达时条目复用旧数据不刷新。
                  }, (root: CommentItem) => `${root.id}:${root.deleted ? 1 : 0}:${this.repliesOf(root.id).length}`)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(12)
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 12 })
          .edgeEffect(EdgeEffect.Spring)
          .layoutWeight(1)

          // 底部评论输入：回复模式下先显示「回复 @昵称」指示条，可一键取消
          Column() {
            if (this.hasReplyTarget()) {
              Row({ space: 6 }) {
                Text(`回复 @${this.replyToNickname()}：`)
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .layoutWeight(1)
                Text('×')
                  .fontSize(16)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .onClick(() => {
                    this.cancelReply();
                  })
              }
              .width('100%')
              .padding({ left: 4, right: 4, bottom: 6 })
            }
            Row({ space: 10 }) {
              TextInput({
                placeholder: this.hasReplyTarget() ? `回复 @${this.replyToNickname()}：` : '友善评论，温暖校园',
                text: $$this.commentText
              })
                .key('commentInput')
                .layoutWeight(1)
                .height(40)
                .backgroundColor(AppColors.PAGE_BG)
                .borderRadius(20)
              Button('发送')
                .height(40)
                .fontSize(14)
                .backgroundColor(this.commentText.trim().length > 0 ? AppColors.PRIMARY : '#9AB6EA')
                .enabled(this.commentText.trim().length > 0 && !this.sending)
                .onClick(() => {
                  this.sendComment();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(AppColors.CARD_BG)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
