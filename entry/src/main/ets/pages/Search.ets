import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { Post, PublicSettings, PostDetailParam } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { PostCard } from '../components/business/PostCard';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';

@Component
export struct SearchPage {
  @Consume('navStack') navStack: NavPathStack;
  @StorageLink('xsnbb_post_revision') @Watch('onPostRevisionChange') postRevision: number = 0;
  @Prop initialKeyword: string = '';
  @State keyword: string = '';
  @State results: Post[] = [];
  @State hotTopics: string[] = [];
  @State searching: boolean = false;
  @State searched: boolean = false;

  aboutToAppear(): void {
    this.loadHotTopics();
    if (this.initialKeyword.length > 0) {
      this.keyword = this.initialKeyword;
      this.doSearch();
    }
  }

  private onPostRevisionChange(): void {
    if (this.searched && !this.searching) {
      this.doSearch();
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async loadHotTopics(): Promise<void> {
    try {
      const settings: PublicSettings = await Api.publicSettings();
      this.hotTopics = settings.hot_topics;
    } catch {
    }
  }

  private async doSearch(): Promise<void> {
    const query = this.keyword.trim();
    if (query.length === 0 || this.searching) {
      return;
    }
    this.searching = true;
    try {
      const resp = await Api.listPosts(query, false);
      this.results = resp.items;
      this.searched = true;
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '搜索失败');
    } finally {
      this.searching = false;
    }
  }

  private patchPost(updated: Post): void {
    this.results = this.results.map((post: Post) => post.id === updated.id ? updated : post);
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 10 }) {
          Text('‹')
            .fontSize(26)
            .fontColor(AppColors.TEXT_PRIMARY)
            .onClick(() => {
              this.navStack.pop();
            })
          TextInput({ placeholder: '搜索帖子内容 / 标签', text: $$this.keyword })
            .layoutWeight(1)
            .height(38)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(19)
            .onSubmit(() => {
              this.doSearch();
            })
          Text('搜索')
            .fontSize(14)
            .fontColor(AppColors.PRIMARY)
            .onClick(() => {
              this.doSearch();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 12, bottom: 8 })

        if (this.searching) {
          LoadingView({ text: '搜索中…' })
        } else if (!this.searched) {
          Column({ space: 12 }) {
            if (this.hotTopics.length > 0) {
              Text('热门话题')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.hotTopics, (topic: string) => {
                  Text(`# ${topic}`)
                    .fontSize(13)
                    .fontColor(AppColors.PRIMARY)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .backgroundColor(AppColors.CARD_BG)
                    .borderRadius(14)
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => {
                      this.keyword = topic;
                      this.doSearch();
                    })
                }, (topic: string) => topic)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(16)
        } else if (this.results.length === 0) {
          EmptyState({ title: '没有找到相关帖子', desc: '换个关键词试试' })
        } else {
          List({ space: 12 }) {
            ForEach(this.results, (post: Post) => {
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
                    this.keyword = tag;
                    this.doSearch();
                  }
                })
              }
            }, (post: Post) => `${post.id}`)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
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
