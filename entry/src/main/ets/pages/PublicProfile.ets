import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { ChatParam, Post, PostDetailParam, PublicAccount, ReportParam } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { AvatarView } from '../components/common/AvatarView';
import { BadgeView } from '../components/common/BadgeView';
import { PostCard } from '../components/business/PostCard';
import { NavBar } from '../components/common/NavBar';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { Session } from '../service/Session';

@Component
export struct PublicProfilePage {
  @Consume('navStack') navStack: NavPathStack;
  @Prop userId: number = 0;
  @State user: PublicAccount | null = null;
  @State posts: Post[] = [];
  @State loading: boolean = true;
  @State startingChat: boolean = false;

  aboutToAppear(): void { this.load(); }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // 系统提示不可用时不影响业务请求。
    }
  }

  private isSelf(): boolean { return this.user?.id === (Session.currentAccount()?.id ?? -1); }

  private async load(): Promise<void> {
    try {
      const resp = await Api.getUser(this.userId);
      this.user = resp.user;
      this.posts = resp.posts;
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '用户资料加载失败');
    }
    this.loading = false;
  }

  private async startChat(): Promise<void> {
    if (!this.user || this.startingChat) return;
    this.startingChat = true;
    try {
      const resp = await Api.startDirectConversation(this.user.id);
      const param: ChatParam = { id: resp.item.id, name: this.user.nickname };
      this.navStack.pushPath({ name: 'Chat', param: param });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '发起私信失败');
    } finally {
      this.startingChat = false;
    }
  }

  private report(): void {
    if (!this.user) return;
    const param: ReportParam = { targetType: 'user', targetId: this.user.id, targetName: this.user.nickname };
    this.navStack.pushPath({ name: 'Report', param: param });
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '个人主页',
          onBack: () => this.navStack.pop(),
          rightText: this.user && !this.isSelf() ? '举报' : '',
          onRight: () => this.report()
        })
        if (this.loading) {
          LoadingView()
        } else if (!this.user) {
          EmptyState({ title: '用户不存在' })
        } else {
          List({ space: 12 }) {
            ListItem() {
              Column({ space: 12 }) {
                AvatarView({ avatar: this.user.avatar, nickname: this.user.nickname, diameter: 72 })
                Row({ space: 6 }) {
                  Text(this.user.nickname).fontSize(21).fontWeight(FontWeight.Bold).fontColor(AppColors.TEXT_PRIMARY)
                  if (this.user.verified) { BadgeView({ badge: this.user.badge ?? 'org' }) }
                }
                Text(this.user.verified ? '已通过学生认证' : '尚未认证')
                  .fontSize(12).fontColor(AppColors.TEXT_SECONDARY)
                if (!this.isSelf()) {
                  Button(this.startingChat ? '正在建立会话…' : '发私信')
                    .height(40).backgroundColor(AppColors.PRIMARY).enabled(!this.startingChat)
                    .onClick(() => this.startChat())
                }
              }
              .width('100%').padding(20).backgroundColor(AppColors.CARD_BG).borderRadius(14)
            }
            ListItem() {
              Text(`公开帖子 ${this.posts.length}`).fontSize(15).fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY).width('100%').padding({ top: 4, bottom: 4 })
            }
            ForEach(this.posts, (post: Post) => {
              ListItem() {
                PostCard({
                  post: post,
                  onOpen: (target: Post) => {
                    const param: PostDetailParam = { id: target.id };
                    this.navStack.pushPath({ name: 'PostDetail', param: param });
                  },
                  onLike: (target: Post) => Api.likePost(target.id).then((r) => this.patchPost(r.post)),
                  onBookmark: (target: Post) => Api.bookmarkPost(target.id).then((r) => this.patchPost(r.post))
                })
              }
            }, (post: Post) => `${post.id}:${post.likes}:${post.comments}:${post.bookmarks}:${post.liked}:${post.bookmarked}`)
          }
          .width('100%').padding(12).layoutWeight(1)
        }
      }
      .width('100%').height('100%').backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }

  private patchPost(updated: Post): void {
    this.posts = this.posts.map((post: Post) => post.id === updated.id ? updated : post);
  }
}
