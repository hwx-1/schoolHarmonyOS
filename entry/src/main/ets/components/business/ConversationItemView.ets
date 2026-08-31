import { DirectConversationItem } from '../../model/Types';
import { TimeUtil } from '../../utils/TimeUtil';
import { AppColors } from '../../constants/AppConfig';
import { AvatarView } from '../common/AvatarView';

/**
 * 私信会话条目：对方头像、昵称、最近一条消息；
 * 未读数冒泡位于卡片右侧、时间下方（未读数由父组件计算后以原始类型传入，保证随状态刷新）。
 */
@Component
export struct ConversationItemView {
  @Prop conversation: DirectConversationItem;
  @Prop unread: number = 0;
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
        Text(this.conversation.other.nickname)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧：时间在上，未读数冒泡在下
      Column({ space: 6 }) {
        Text(TimeUtil.format(this.conversation.updated_at))
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
        if (this.unread > 0) {
          Text(this.unread > 99 ? '99+' : `${this.unread}`)
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
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onOpen(this.conversation))
  }
}
