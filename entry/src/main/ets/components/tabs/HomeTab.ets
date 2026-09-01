import { common } from '@kit.AbilityKit';
import { Api } from '../../service/Api';
import { ApiError } from '../../service/Http';
import { Announcement, CampusTool, Post, PostDetailParam, PublicSettings, SearchParam } from '../../model/Types';
import { AppColors } from '../../constants/AppConfig';
import { PostCard } from '../business/PostCard';
import { LoadingView } from '../common/LoadingView';
import { EmptyState } from '../common/EmptyState';
import { NavBar } from '../common/NavBar';

/** 排序选项 */
interface SortOption {
  key: string;
  label: string;
}

/** 首页信息流：顶部轮播图、常用服务导航、热门话题、帖子列表。 */
@Component
export struct HomeTab {
  @Consume('navStack') navStack: NavPathStack;
  @StorageLink('xsnbb_post_revision') @Watch('onPostRevisionChange') postRevision: number = 0;
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State loadError: string = '';
  @State announcements: Announcement[] = [];
  @State settings: PublicSettings = { hot_topics: [], greeting: '' };
  @State tools: CampusTool[] = [];
  @State posts: Post[] = [];
  @State sortMode: string = 'time';
  private readonly sortOptions: SortOption[] = [
    { key: 'time', label: '最新' },
    { key: 'comments', label: '评论' },
    { key: 'likes', label: '点赞' },
    { key: 'bookmarks', label: '收藏' },
  ];
  private likingIds: Set<number> = new Set<number>();
  private bookmarkingIds: Set<number> = new Set<number>();

  aboutToAppear(): void {
    this.loadAll();
  }

  private onPostRevisionChange(): void {
    if (!this.loading) {
      this.loadPosts();
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
    await this.loadPosts();
    // 轮播图 / 话题 / 工具失败不阻塞信息流
    try {
      const annResp = await Api.listAnnouncements();
      this.announcements = annResp.items.filter((item: Announcement) => item.published);
    } catch {
    }
    try {
      this.settings = await Api.publicSettings();
    } catch {
    }
    try {
      const toolResp = await Api.listTools();
      this.tools = toolResp.items
        .filter((item: CampusTool) => item.enabled)
        .sort((a: CampusTool, b: CampusTool) => b.weight - a.weight)
        .slice(0, 7);
    } catch {
    }
    this.loading = false;
    this.refreshing = false;
  }

  private async loadPosts(): Promise<void> {
    this.loadError = '';
    try {
      const resp = await Api.listPosts('', false);
      this.posts = [...resp.items];
    } catch (err) {
      this.loadError = err instanceof ApiError ? err.message : '加载失败';
    }
  }

  private handleRefresh(): void {
    this.refreshing = true;
    this.loadAll();
  }

  private async handleLike(post: Post): Promise<void> {
    if (this.likingIds.has(post.id)) {
      return;
    }
    this.likingIds.add(post.id);
    this.patchPost(this.toggleLikeSnapshot(post));
    try {
      const resp = await Api.likePost(post.id);
      this.patchPost(resp.post);
    } catch (err) {
      this.patchPost(post);
      this.toast(err instanceof ApiError ? err.message : '操作失败');
    } finally {
      this.likingIds.delete(post.id);
    }
  }

  private async handleBookmark(post: Post): Promise<void> {
    if (this.bookmarkingIds.has(post.id)) {
      return;
    }
    this.bookmarkingIds.add(post.id);
    this.patchPost(this.toggleBookmarkSnapshot(post));
    try {
      const resp = await Api.bookmarkPost(post.id);
      this.patchPost(resp.post);
      this.toast(resp.post.bookmarked ? '已收藏' : '已取消收藏');
    } catch (err) {
      this.patchPost(post);
      this.toast(err instanceof ApiError ? err.message : '操作失败');
    } finally {
      this.bookmarkingIds.delete(post.id);
    }
  }

  private toggleLikeSnapshot(post: Post): Post {
    return {
      id: post.id,
      author: post.author,
      text: post.text,
      images: post.images,
      tags: post.tags,
      status: post.status,
      pinned: post.pinned,
      likes: Math.max(0, post.likes + (post.liked ? -1 : 1)),
      comments: post.comments,
      bookmarks: post.bookmarks,
      liked: !post.liked,
      bookmarked: post.bookmarked,
      created_at: post.created_at,
      updated_at: post.updated_at,
    };
  }

  private toggleBookmarkSnapshot(post: Post): Post {
    return {
      id: post.id,
      author: post.author,
      text: post.text,
      images: post.images,
      tags: post.tags,
      status: post.status,
      pinned: post.pinned,
      likes: post.likes,
      comments: post.comments,
      bookmarks: Math.max(0, post.bookmarks + (post.bookmarked ? -1 : 1)),
      liked: post.liked,
      bookmarked: !post.bookmarked,
      created_at: post.created_at,
      updated_at: post.updated_at,
    };
  }

  private patchPost(updated: Post): void {
    this.posts = this.posts.map((post: Post) => post.id === updated.id ? updated : post);
  }

  /** 按当前排序模式返回帖子列表；置顶帖始终保持在前面。 */
  private sortedPosts(): Post[] {
    const list: Post[] = [...this.posts];
    if (this.sortMode === 'comments') {
      list.sort((a: Post, b: Post) => b.comments - a.comments);
    } else if (this.sortMode === 'likes') {
      list.sort((a: Post, b: Post) => b.likes - a.likes);
    } else if (this.sortMode === 'bookmarks') {
      // 按收藏总数排序（服务端 Post.bookmarks）
      list.sort((a: Post, b: Post) => b.bookmarks - a.bookmarks);
    } else {
      // 默认时间顺序（服务端返回即时间序，此处再兜底按时间倒序）
      list.sort((a: Post, b: Post) => b.created_at.localeCompare(a.created_at));
    }
    // 置顶帖保持在最前
    return list.sort((a: Post, b: Post) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
  }

  private postRenderKey(post: Post): string {
    return `${post.id}_${post.likes}_${post.comments}_${post.bookmarks}` +
      `_${post.liked ? 1 : 0}_${post.bookmarked ? 1 : 0}_${post.pinned ? 1 : 0}`;
  }

  private openSearch(tag: string): void {
    const param: SearchParam = { keyword: tag };
    this.navStack.pushPath({ name: 'Search', param: param });
  }

  private async openTool(tool: CampusTool): Promise<void> {
    if (!tool.url || tool.url.length === 0) {
      this.toast('该工具暂未开放链接');
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await context.openLink(tool.url);
    } catch {
      this.toast('无法打开该链接');
    }
  }

  private toolIcon(tool: CampusTool): string {
    if (tool.icon.length > 0) {
      return tool.icon;
    }
    return tool.type === 'link' ? '🔗' : '🧰';
  }

  /** 常用服务区行数：AI 助手 + 工具每排 4 个，最多 2 排；只有 1 排时内容区自动向上补齐。 */
  private toolRows(): number {
    return Math.min(2, Math.max(1, Math.ceil((this.tools.length + 1) / 4)));
  }

  build() {
    Column() {
      // 顶部：与消息页一致的居中标题栏
      NavBar({ title: '沈大社区', showBack: false })

      // 搜索入口
      Row() {
        Row({ space: 6 }) {
          Image($r('app.media.ic_search'))
            .width(15)
            .height(15)
            .fillColor(AppColors.TEXT_SECONDARY)
          Text('搜索帖子 / 话题')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .height(38)
        .layoutWeight(1)
        .padding({ left: 14 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(19)
        .onClick(() => {
          const param: SearchParam = { keyword: '' };
          this.navStack.pushPath({ name: 'Search', param: param });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 4 })

      // 排序筛选栏：默认时间顺序，可切换评论 / 点赞 / 收藏
      Row({ space: 8 }) {
        ForEach(this.sortOptions, (option: SortOption) => {
          Text(option.label)
            .fontSize(13)
            .fontColor(this.sortMode === option.key ? Color.White : AppColors.TEXT_SECONDARY)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.sortMode === option.key ? AppColors.PRIMARY : AppColors.CARD_BG)
            .borderRadius(15)
            .onClick(() => {
              this.sortMode = option.key;
            })
        }, (option: SortOption) => option.key)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })

      if (this.loading) {
        LoadingView()
      } else if (this.loadError.length > 0 && this.posts.length === 0) {
        EmptyState({
          title: '加载失败',
          desc: this.loadError,
          actionText: '重试',
          onAction: () => this.loadAll()
        })
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 8 }) {
            // 顶部轮播图：最新公告
            if (this.announcements.length > 0) {
              ListItem() {
                Swiper() {
                  ForEach(this.announcements.slice(0, 3), (item: Announcement) => {
                    Column({ space: 8 }) {
                      Text(item.title)
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      Text(item.summary)
                        .fontSize(12)
                        .fontColor('#E6FFFFFF')
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                    }
                    .width('100%')
                    .height('100%')
                    .alignItems(HorizontalAlign.Start)
                    .justifyContent(FlexAlign.End)
                    .padding(18)
                    .linearGradient({
                      direction: GradientDirection.RightBottom,
                      colors: [[AppColors.PRIMARY, 0.0], ['#5B8DEF', 1.0]],
                    })
                    .borderRadius(14)
                    .onClick(() => {
                      this.navStack.pushPath({ name: 'Announcements' });
                    })
                  }, (item: Announcement) => `${item.id}`)
                }
                .autoPlay(true)
                .loop(true)
                .interval(4)
                .duration(350)
                .indicator(Indicator.dot()
                  .selectedColor(Color.White)
                  .color('#80FFFFFF'))
                .width('100%')
                .height(150)
              }
            }

            // 常用服务导航：AI 助手 + 常用工具，4 列最多 2 排
            ListItem() {
              Grid() {
                GridItem() {
                  Column({ space: 6 }) {
                    Image($r('app.media.ic_sparkle'))
                      .width(24)
                      .height(24)
                      .fillColor(AppColors.PRIMARY)
                    Text('AI 助手')
                      .fontSize(12)
                      .fontColor(AppColors.TEXT_PRIMARY)
                      .maxLines(1)
                  }
                  .width('100%')
                  .padding({ top: 14, bottom: 14 })
                  .backgroundColor(AppColors.CARD_BG)
                  .borderRadius(12)
                  .onClick(() => {
                    this.navStack.pushPath({ name: 'AI' });
                  })
                }
                ForEach(this.tools, (tool: CampusTool) => {
                  GridItem() {
                    Column({ space: 6 }) {
                      Text(this.toolIcon(tool))
                        .fontSize(24)
                      Text(tool.name)
                        .fontSize(12)
                        .fontColor(AppColors.TEXT_PRIMARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .width('100%')
                    .padding({ top: 14, bottom: 14 })
                    .backgroundColor(AppColors.CARD_BG)
                    .borderRadius(12)
                    .onClick(() => {
                      this.openTool(tool);
                    })
                  }
                }, (tool: CampusTool) => `${tool.id}`)
              }
              .columnsTemplate('1fr 1fr 1fr 1fr')
              .rowsTemplate(this.toolRows() > 1 ? '1fr 1fr' : '1fr')
              .columnsGap(10)
              .rowsGap(10)
              .width('100%')
              .height(this.toolRows() > 1 ? 170 : 80)
            }

            // 热门话题
            if (this.settings.hot_topics.length > 0) {
              ListItem() {
                Scroll() {
                  Row({ space: 8 }) {
                    ForEach(this.settings.hot_topics, (topic: string) => {
                      Text(`# ${topic}`)
                        .fontSize(12)
                        .fontColor(AppColors.PRIMARY)
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                        .backgroundColor(AppColors.CARD_BG)
                        .borderRadius(14)
                        .onClick(() => this.openSearch(topic))
                    }, (topic: string) => topic)
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')
              }
            }

            ForEach(this.sortedPosts(), (post: Post) => {
              ListItem() {
                PostCard({
                  post: post,
                  onOpen: (target: Post) => {
                    const param: PostDetailParam = { id: target.id };
                    this.navStack.pushPath({ name: 'PostDetail', param: param });
                  },
                  onLike: (target: Post) => {
                    this.handleLike(target);
                  },
                  onBookmark: (target: Post) => {
                    this.handleBookmark(target);
                  },
                  onTag: (tag: string) => this.openSearch(tag)
                })
              }
            }, (post: Post) => this.postRenderKey(post))

            if (this.posts.length === 0) {
              ListItem() {
                EmptyState({ title: '还没有帖子', desc: '来发第一条校园动态吧' })
              }
            }
          }
          .width('100%')
          .cachedCount(3)
          .padding({ left: 12, right: 12, bottom: 12 })
        }
        .onRefreshing(() => this.handleRefresh())
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}
