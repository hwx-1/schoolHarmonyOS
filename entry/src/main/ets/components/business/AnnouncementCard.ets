import { Announcement } from '../../model/Types';
import { TimeUtil } from '../../utils/TimeUtil';
import { AppColors } from '../../constants/AppConfig';

/** 公告卡片，点击展开全文。 */
@Component
export struct AnnouncementCard {
  @Prop announcement: Announcement;
  @State expanded: boolean = false;

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('📢')
          .fontSize(14)
        Text(this.announcement.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      Text(this.expanded ? this.announcement.body : this.announcement.summary)
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
        .maxLines(this.expanded ? 999 : 2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        Text(TimeUtil.format(this.announcement.created_at))
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        Text(this.expanded ? '收起' : '展开')
          .fontSize(12)
          .fontColor(AppColors.PRIMARY)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.expanded = !this.expanded;
    })
  }
}
