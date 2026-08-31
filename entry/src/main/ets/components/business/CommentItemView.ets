import { CommentItem } from '../../model/Types';
import { TimeUtil } from '../../utils/TimeUtil';
import { AppColors } from '../../constants/AppConfig';
import { AvatarView } from '../common/AvatarView';
import { BadgeView } from '../common/BadgeView';

/** 评论条目。 */
@Component
export struct CommentItemView {
  @Prop comment: CommentItem;

  build() {
    Row({ space: 10 }) {
      AvatarView({
        avatar: this.comment.author.avatar,
        nickname: this.comment.author.nickname,
        diameter: 32
      })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(this.comment.deleted ? '用户' : this.comment.author.nickname)
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
          if (!this.comment.deleted && this.comment.author.verified) {
            BadgeView({ badge: this.comment.author.badge ?? 'org' })
          }
          Text(TimeUtil.format(this.comment.created_at))
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        Text(this.comment.deleted ? '该评论已删除' : this.comment.text)
          .fontSize(14)
          .fontColor(this.comment.deleted ? AppColors.TEXT_SECONDARY : AppColors.TEXT_PRIMARY)
          .fontStyle(this.comment.deleted ? FontStyle.Italic : FontStyle.Normal)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
  }
}
