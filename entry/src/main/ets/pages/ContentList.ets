import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { Post, PostDetailParam, SearchParam } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { PostCard } from '../components/business/PostCard';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { NavBar } from '../components/common/NavBar';

/** 通用内容列表：mode = mine（我的帖子）/ bookmarks（我的收藏）。 */
@Component
export struct ContentListPage {
  @Consume('navStack') navStack: NavPathStack;
  @StorageLink('xsnbb_post_revision') @Watch('onPostRevisionChange') postRevision: number = 0;
  @Prop mode: string = 'mine';
  @State items: Post[] = [];
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State loadError: string = '';

  private title(): string {
    return this.mode === 'bookmarks' ? '我的收藏' : '我的帖子';
  }

  aboutToAppear(): void {
    this.load();
  }

  private onPostRevisionChange(): void {
    if (!this.loading) {
      this.load();
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async load(): Promise<void> {
    this.loadError = '';
    try {
      const resp = this.mode === 'bookmarks'
        ? await Api.myBookmarks()
        : await Api.listPosts('', true);
      this.items = resp.items;
    } catch (err) {
      this.loadError = err instanceof ApiError ? err.message : '加载失败';
    }
    this.loading = false;
    this.refreshing = false;
  }

  private patchPost(updated: Post): void {
    this.items = this.items.map((post: Post) => post.id === updated.id ? updated : post);
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: this.title(),
          onBack: () => {
            this.navStack.pop();
          }
        })

        if (this.loading) {
          LoadingView()
        } else if (this.loadError.length > 0 && this.items.length === 0) {
          EmptyState({
            title: '加载失败',
            desc: this.loadError,
            actionText: '重试',
            onAction: () => this.load()
          })
        } else {
          Refresh({ refreshing: $$this.refreshing }) {
            List({ space: 12 }) {
              ForEach(this.items, (post: Post) => {
                ListItem() {
                  PostCard({
                    post: post,
                    onOpen: (target: Post) => {
                      const param: PostDetailParam = { id: target.id };
                      this.navStack.pushPath({ name: 'PostDetail', param: param });
                    },
                    onLike: (target: Post) => {
                      Api.likePost(target.id)
                        .then((resp) => this.patchPost(resp.post))
                        .catch(() => this.toast('操作失败'));
                    },
                    onBookmark: (target: Post) => {
                      Api.bookmarkPost(target.id)
                        .then((resp) => this.patchPost(resp.post))
                        .catch(() => this.toast('操作失败'));
                    },
                    onTag: (tag: string) => {
                      const param: SearchParam = { keyword: tag };
                      this.navStack.pushPath({ name: 'Search', param: param });
                    }
                  })
                }
              // 键值必须包含驱动卡片渲染的字段：仅用帖子 id 时 ArkUI 复用旧组件，
              // 点赞/收藏/评论数变化不会刷新（与消息页未读冒泡同一类问题）。
              }, (post: Post) => `${post.id}:${post.likes}:${post.comments}:${post.bookmarks}:` +
                `${post.liked ? 1 : 0}:${post.bookmarked ? 1 : 0}:${post.pinned ? 1 : 0}`)
              if (this.items.length === 0) {
                ListItem() {
                  EmptyState({
                    title: this.mode === 'bookmarks' ? '还没有收藏' : '还没有发布过帖子'
                  })
                }
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12 })
          }
          .onRefreshing(() => {
            this.refreshing = true;
            this.load();
          })
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
