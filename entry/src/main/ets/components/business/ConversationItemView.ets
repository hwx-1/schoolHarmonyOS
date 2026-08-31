import { DirectConversationItem } from '../../model/Types';
import { TimeUtil } from '../../utils/TimeUtil';
import { AppColors } from '../../constants/AppConfig';
import { AvatarView } from '../common/AvatarView';

/** 私信会话条目：对方头像、昵称、最近一条消息。 */
@Component
export struct ConversationItemView {
  @Prop conversation: DirectConversationItem;
  onOpen: (conversation: DirectConversationItem) => void = () => {};

  private lastMessage(): string {
    const messages = this.conversation.messages;
    if (messages.length === 0) {
      return '开始聊天吧';
    }
    const last = messages[messages.length - 1];
    return last.system ? '[系统招呼]' : last.text;
  }

  build() {
    Row({ space: 12 }) {
      AvatarView({
        avatar: this.conversation.other.avatar,
        nickname: this.conversation.other.nickname,
        diameter: 46
      })
      Column({ space: 4 }) {
        Row() {
          Text(this.conversation.other.nickname)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)
          Text(TimeUtil.format(this.conversation.updated_at))
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        Row({ space: 6 }) {
          Text(this.lastMessage())
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.conversation.unlocked) {
            Text('自由聊')
              .fontSize(10)
              .fontColor('#0A8A4D')
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor('#140A8A4D')
              .borderRadius(4)
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(20)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onOpen(this.conversation))
  }
}
