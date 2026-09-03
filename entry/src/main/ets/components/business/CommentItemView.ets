import { CommentItem } from '../../model/Types';
import { TimeUtil } from '../../utils/TimeUtil';
import { AppColors } from '../../constants/AppConfig';
import { AvatarView } from '../common/AvatarView';
import { BadgeView } from '../common/BadgeView';

/**
 * 评论条目（抖音式两级评论）：
 * 主评论正常大小；回复缩进、头像更小；回复另一条回复时昵称后带「回复 @对方」。
 * 点「回复」由父页面把输入框切换为回复模式。
 */
@Component
export struct CommentItemView {
  @Prop comment: CommentItem;
  /** 回复对象昵称：仅回复另一条回复时展示（直接回复主评论不展示）。 */
  @Prop replyToName: string = '';
  /** 是否回复条目：头像更小、整体更紧凑。 */
  @Prop isReply: boolean = false;
  onReply: (comment: CommentItem) => void = () => {};
  onAuthor: (comment: CommentItem) => void = () => {};
  onReport: (comment: CommentItem) => void = () => {};

  build() {
    Row({ space: 10 }) {
      AvatarView({
        avatar: this.comment.author.avatar,
        nickname: this.comment.author.nickname,
        diameter: this.isReply ? 24 : 32
      })
      .onClick(() => {
        if (!this.comment.deleted) this.onAuthor(this.comment);
      })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(this.comment.deleted ? '用户' : this.comment.author.nickname)
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .onClick(() => {
              if (!this.comment.deleted) this.onAuthor(this.comment);
            })
          if (!this.comment.deleted && this.replyToName.length > 0) {
            Text(`回复 ${this.replyToName}`)
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          if (!this.comment.deleted && this.comment.author.verified) {
            BadgeView({ badge: this.comment.author.badge ?? 'org' })
          }
        }
        Text(this.comment.deleted ? '该评论已删除' : this.comment.text)
          .fontSize(14)
          .fontColor(this.comment.deleted ? AppColors.TEXT_SECONDARY : AppColors.TEXT_PRIMARY)
          .fontStyle(this.comment.deleted ? FontStyle.Italic : FontStyle.Normal)
        Row({ space: 12 }) {
          Text(TimeUtil.format(this.comment.created_at))
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
          if (!this.comment.deleted) {
            Text('回复')
              .fontSize(11)
              .fontColor(AppColors.TEXT_SECONDARY)
              .onClick(() => this.onReply(this.comment))
            Text('举报')
              .fontSize(11)
              .fontColor(AppColors.TEXT_SECONDARY)
              .onClick(() => this.onReport(this.comment))
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
  }
}
