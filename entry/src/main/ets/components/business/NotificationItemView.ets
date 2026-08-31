import { AppNotification } from '../../model/Types';
import { TimeUtil } from '../../utils/TimeUtil';
import { AppColors } from '../../constants/AppConfig';

/** 系统通知条目。 */
@Component
export struct NotificationItemView {
  @Prop notification: AppNotification;
  onOpen: (notification: AppNotification) => void = () => {};

  private typeLabel(): string {
    switch (this.notification.type) {
      case 'comment':
        return '评论';
      case 'reply':
        return '回复';
      case 'like':
        return '赞同';
      case 'report_result':
        return '举报结果';
      case 'official_answer':
        return '官方答复';
      case 'punishment':
        return '处罚通知';
      case 'appeal_result':
        return '申诉结果';
      default:
        return '通知';
    }
  }

  private typeIcon(): string {
    switch (this.notification.type) {
      case 'like':
        return '♥';
      case 'comment':
      case 'reply':
        return '●';
      case 'punishment':
      case 'appeal_result':
        return '!';
      default:
        return '✦';
    }
  }

  private typeColor(): string {
    switch (this.notification.type) {
      case 'like':
        return '#E5484D';
      case 'comment':
      case 'reply':
        return AppColors.PRIMARY;
      case 'punishment':
        return AppColors.ORANGE;
      default:
        return '#7C5CFC';
    }
  }

  build() {
    Row({ space: 12 }) {
      Stack() {
        Text(this.typeIcon())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.typeColor())
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor('#F3F4F8')

      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(this.notification.title)
            .fontSize(15)
            .fontWeight(this.notification.read ? FontWeight.Normal : FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (!this.notification.read) {
            Text('1')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .height(16)
              .constraintSize({ minWidth: 16 })
              .padding({ left: 4, right: 4 })
              .backgroundColor(AppColors.DANGER)
              .borderRadius(8)
          }
        }
        if (this.notification.body.length > 0) {
          Text(this.notification.body)
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Row({ space: 6 }) {
          Text(this.typeLabel())
            .fontSize(11)
            .fontColor(this.typeColor())
          Text('·')
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
          Text(TimeUtil.format(this.notification.created_at))
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .alignItems(VerticalAlign.Top)
    .onClick(() => this.onOpen(this.notification))
  }
}
