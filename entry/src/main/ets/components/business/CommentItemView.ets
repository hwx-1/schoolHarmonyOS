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

  build() {
    Row({ space: 10 }) {
      AvatarView({
        avatar: this.comment.author.avatar,
        nickname: this.comment.author.nickname,
        diameter: this.isReply ? 24 : 32
      })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(this.comment.deleted ? '用户' : this.comment.author.nickname)
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
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
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      // 抖音交互：点评论卡片任意位置即进入回复模式（父页面负责唤起键盘）。
      if (!this.comment.deleted) {
        this.onReply(this.comment);
      }
    })
  }
}
