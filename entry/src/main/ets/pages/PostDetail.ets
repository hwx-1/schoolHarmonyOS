import { Api } from '../service/Api';
import { ApiError, absoluteMediaUrl } from '../service/Http';
import { CommentItem, Post, SearchParam } from '../model/Types';
import { TimeUtil } from '../utils/TimeUtil';
import { AppColors } from '../constants/AppConfig';
import { AvatarView } from '../components/common/AvatarView';
import { BadgeView } from '../components/common/BadgeView';
import { TagChip } from '../components/common/TagChip';
import { CommentItemView } from '../components/business/CommentItemView';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';

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
      const resp = await Api.createComment(this.postId, text);
      if (!resp.moderation.pass) {
        this.toast(resp.message || '评论未通过内容审核');
      } else {
        this.comments = [...this.comments, resp.comment];
        this.commentText = '';
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

  build() {
    NavDestination() {
      Column() {
        // 顶部栏
        Row() {
          Text('‹')
            .fontSize(26)
            .fontColor(AppColors.TEXT_PRIMARY)
            .padding({ right: 12 })
            .onClick(() => {
              this.navStack.pop();
            })
          Text('帖子详情')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 12, bottom: 8 })

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
                    Text(this.post.liked ? `已赞同 ${this.post.likes}` : `赞同 ${this.post.likes}`)
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
                    Text(this.post.bookmarked ? '已收藏' : '收藏')
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
              // 评论区
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
                  ForEach(this.comments, (item: CommentItem) => {
                    CommentItemView({ comment: item })
                  }, (item: CommentItem) => `${item.id}`)
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

          // 底部评论输入
          Row({ space: 10 }) {
            TextInput({ placeholder: '友善评论，温暖校园', text: $$this.commentText })
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
