import { DirectMessage } from '../../model/Types';
import { AppColors } from '../../constants/AppConfig';

/** 聊天气泡：区分我 / 对方 / 系统消息。 */
@Component
export struct MessageBubble {
  @Prop message: DirectMessage;
  @Prop isMine: boolean = false;

  build() {
    if (this.message.system) {
      Row() {
        Text(this.message.text.length > 0 ? this.message.text : '👋 对方发来一个系统招呼')
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#0D000000')
          .borderRadius(12)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 6, bottom: 6 })
    } else {
      Row() {
        Text(this.message.text)
          .fontSize(15)
          .fontColor(this.isMine ? Color.White : AppColors.TEXT_PRIMARY)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor(this.isMine ? AppColors.PRIMARY : AppColors.CARD_BG)
          .borderRadius(14)
          .constraintSize({ maxWidth: '72%' })
      }
      .width('100%')
      .justifyContent(this.isMine ? FlexAlign.End : FlexAlign.Start)
      .margin({ top: 6, bottom: 6 })
    }
  }
}
