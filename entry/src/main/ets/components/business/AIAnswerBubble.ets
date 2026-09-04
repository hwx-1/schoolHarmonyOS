import { AppColors } from '../../constants/AppConfig';
import { AIText } from '../../utils/AIText';

/**
 * AI 回答气泡：白卡 + 细边框，思考过程可收起/展开（默认收起），正文在思考过程下方，
 * 正文渲染前经 AIText.formatAnswer 去除 Markdown 记号。
 * 既用于已持久化的消息，也用于流式生成中的临时气泡（showSpinner 在尚无任何增量时显示转圈）。
 */
@Component
export struct AIAnswerBubble {
  @Prop reasoning: string = '';
  @Prop text: string = '';
  @Prop source: string = '';
  @Prop showSpinner: boolean = false;
  /** 知识库命中待确认：显示「有帮助 / 联网重答」。 */
  @Prop needsFeedback: boolean = false;
  /** 已反馈结果：yes / no。 */
  @Prop feedback: string = '';
  /** 页面级反馈锁：任一消息反馈进行中时禁用全部反馈按钮。 */
  @Prop feedbackLocked: boolean = false;
  /** 当前这条消息正在联网重答。 */
  @Prop feedbackBusy: boolean = false;
  onFeedback: (satisfied: boolean) => void = () => {};
  @State expanded: boolean = false;

  build() {
    Column({ space: 8 }) {
      if (this.reasoning.length > 0) {
        Row() {
          Text('思考过程')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
          Blank()
          Text(this.expanded ? '收起' : '展开')
            .fontSize(12)
            .fontColor(AppColors.PRIMARY)
        }
        .width('100%')
        .onClick(() => {
          this.expanded = !this.expanded;
        })

        if (this.expanded) {
          Text(this.reasoning)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(AppColors.TEXT_SECONDARY)
            .width('100%')
        }
      }

      if (this.text.length > 0) {
        Text(AIText.formatAnswer(this.text))
          .fontSize(15)
          .lineHeight(22)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
      }

      if (this.showSpinner) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(AppColors.PRIMARY)
          Text('正在思考…')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .alignItems(VerticalAlign.Center)
      }

      if (this.source.length > 0) {
        Row({ space: 12 }) {
          Text(this.source)
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
          Text('内容由 AI 生成，请仔细甄别')
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .width('100%')
      }

      if (this.needsFeedback) {
        Column({ space: 8 }) {
          Text('这个答案是你想要的吗？')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
          Row({ space: 10 }) {
            Button('有帮助')
              .height(32)
              .fontSize(12)
              .backgroundColor(AppColors.PRIMARY)
              .enabled(!this.feedbackLocked)
              .onClick(() => this.onFeedback(true))
            Button(this.feedbackBusy ? '正在检索…' : '联网重答')
              .height(32)
              .fontSize(12)
              .fontColor(AppColors.PRIMARY)
              .backgroundColor('#E8EFFC')
              .enabled(!this.feedbackLocked)
              .onClick(() => this.onFeedback(false))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else if (this.feedback === 'yes') {
        Text('已确认：知识库答案有帮助')
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
      } else if (this.feedback === 'no') {
        Text('已反馈：知识库答案未解决问题')
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(16)
    .border({ width: 1, color: AppColors.DIVIDER })
    .alignItems(HorizontalAlign.Start)
  }
}
