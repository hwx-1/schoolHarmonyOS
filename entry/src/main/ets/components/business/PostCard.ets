import { Post } from '../../model/Types';
import { TimeUtil } from '../../utils/TimeUtil';
import { absoluteMediaUrl } from '../../service/Http';
import { AppColors } from '../../constants/AppConfig';
import { AvatarView } from '../common/AvatarView';
import { BadgeView } from '../common/BadgeView';
import { TagChip } from '../common/TagChip';

/**
 * 信息流帖子卡片（知乎内容页风格）：
 * 扁平白色卡片、无圆角阴影，赞同/评论/收藏文字操作栏；
 * 操作按钮直接绑定业务回调，确保列表外层无需进入详情即可点赞。
 */
@Component
export struct PostCard {
  @Prop post: Post;
  onOpen: (post: Post) => void = () => {};
  onLike: (post: Post) => void = () => {};
  onBookmark: (post: Post) => void = () => {};
  onTag: (tag: string) => void = () => {};

  private imageUrls(): string[] {
    if (!this.post.images) {
      return [];
    }
    return this.post.images.map((path: string) => absoluteMediaUrl(path));
  }

  private imageSpan(): number {
    const count = this.imageUrls().length;
    if (count === 1) {
      return 1;
    }
    return count === 2 || count === 4 ? 2 : 3;
  }

  build() {
    Column({ space: 10 }) {
      // 作者行
      Row({ space: 10 }) {
        AvatarView({ avatar: this.post.author.avatar, nickname: this.post.author.nickname, diameter: 40 })
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(this.post.author.nickname)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
            if (this.post.author.verified) {
              BadgeView({ badge: this.post.author.badge ?? 'org' })
            }
            if (this.post.pinned) {
              Text('置顶')
                .fontSize(10)
                .fontColor(AppColors.ORANGE)
                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                .border({ width: 1, color: AppColors.ORANGE, radius: 4 })
            }
          }
          Text(TimeUtil.format(this.post.created_at))
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .onClick(() => this.onOpen(this.post))

      // 正文
      Text(this.post.text ?? '')
        .fontSize(15)
        .fontColor(AppColors.TEXT_PRIMARY)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => this.onOpen(this.post))

      // 图片九宫格
      if (this.imageUrls().length > 0) {
        Grid() {
          ForEach(this.imageUrls(), (url: string) => {
            GridItem() {
              Image(url)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
            }
          }, (url: string) => url)
        }
        .columnsTemplate(`1fr `.repeat(this.imageSpan()).trim())
        .columnsGap(6)
        .rowsGap(6)
        .onClick(() => this.onOpen(this.post))
      }

      // 标签
      if (this.post.tags && this.post.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.post.tags, (tag: string) => {
            TagChip({ text: tag, onTap: this.onTag })
              .margin({ right: 8, bottom: 4 })
          }, (tag: string) => tag)
        }
      }

      // 操作栏：知乎风格 赞同 / 评论 / 收藏
      Row({ space: 8 }) {
        Button({ type: ButtonType.Capsule }) {
          Row({ space: 5 }) {
            Image($r('app.media.ic_heart'))
              .width(16)
              .height(16)
              .fillColor(this.post.liked ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
            Text(`${this.post.likes}`)
              .fontSize(13)
              .fontColor(this.post.liked ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .height(38)
        .backgroundColor(this.post.liked ? '#142E6BE6' : '#F4F5F7')
        .onClick(() => this.onLike(this.post))

        Button({ type: ButtonType.Capsule }) {
          Row({ space: 5 }) {
            Image($r('app.media.ic_comment'))
              .width(16)
              .height(16)
              .fillColor(AppColors.TEXT_SECONDARY)
            Text(`${this.post.comments}`)
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .height(38)
        .backgroundColor('#F4F5F7')
        .onClick(() => this.onOpen(this.post))

        Button({ type: ButtonType.Capsule }) {
          Row({ space: 5 }) {
            Image($r('app.media.ic_star'))
              .width(16)
              .height(16)
              .fillColor(this.post.bookmarked ? AppColors.ORANGE : AppColors.TEXT_SECONDARY)
            Text(`${this.post.bookmarks}`)
              .fontSize(13)
              .fontColor(this.post.bookmarked ? AppColors.ORANGE : AppColors.TEXT_SECONDARY)
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .height(38)
        .backgroundColor(this.post.bookmarked ? '#14FF6B00' : '#F4F5F7')
        .onClick(() => this.onBookmark(this.post))
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.CARD_BG)
    .alignItems(HorizontalAlign.Start)
  }

}
