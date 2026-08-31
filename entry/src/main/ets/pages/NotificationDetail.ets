import { AppColors } from '../constants/AppConfig';
import { AppNotification, PostDetailParam } from '../model/Types';
import { NavBar } from '../components/common/NavBar';
import { TimeUtil } from '../utils/TimeUtil';

/** 通知详情：承载所有通知类型，并为有关联帖子的消息提供二级入口。 */
@Component
export struct NotificationDetailPage {
  @Consume('navStack') navStack: NavPathStack;
  @Prop notification: AppNotification;

  private typeLabel(): string {
    switch (this.notification.type) {
      case 'like':
        return '赞同通知';
      case 'comment':
        return '评论通知';
      case 'reply':
        return '回复通知';
      case 'report_result':
        return '举报处理结果';
      case 'official_answer':
        return '官方答复';
      case 'punishment':
        return '账号处罚';
      case 'appeal_result':
        return '申诉结果';
      default:
        return '系统通知';
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
        return AppColors.DANGER;
      case 'comment':
      case 'reply':
        return AppColors.PRIMARY;
      case 'punishment':
        return AppColors.ORANGE;
      default:
        return '#7C5CFC';
    }
  }

  private canOpenPost(): boolean {
    return this.notification.ref_type === 'post' && this.notification.ref_id !== undefined;
  }

  private openRelatedPost(): void {
    if (!this.canOpenPost() || this.notification.ref_id === undefined) {
      return;
    }
    const param: PostDetailParam = { id: this.notification.ref_id };
    this.navStack.pushPath({ name: 'PostDetail', param: param });
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '通知详情',
          onBack: () => {
            this.navStack.pop();
          }
        })

        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 14 }) {
              Row({ space: 12 }) {
                Stack() {
                  Text(this.typeIcon())
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.typeColor())
                }
                .width(52)
                .height(52)
                .borderRadius(26)
                .backgroundColor('#F3F4F8')

                Column({ space: 4 }) {
                  Text(this.typeLabel())
                    .fontSize(12)
                    .fontColor(this.typeColor())
                  Text(TimeUtil.format(this.notification.created_at))
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')

              Divider().color(AppColors.DIVIDER)

              Text(this.notification.title)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')

              Text(this.notification.body.length > 0 ? this.notification.body : '暂无更多内容')
                .fontSize(15)
                .lineHeight(24)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%')
            }
            .width('100%')
            .padding(20)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(16)

            if (this.canOpenPost()) {
              Button('查看相关帖子')
                .width('100%')
                .height(46)
                .fontSize(15)
                .backgroundColor(AppColors.PRIMARY)
                .onClick(() => this.openRelatedPost())
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 24 })
        }
        .align(Alignment.Top)
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
