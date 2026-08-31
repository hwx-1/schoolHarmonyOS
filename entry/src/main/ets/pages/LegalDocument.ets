import { AppColors } from '../constants/AppConfig';
import { NavBar } from '../components/common/NavBar';

interface LegalSection {
  title: string;
  body: string;
}

const PRIVACY_SECTIONS: LegalSection[] = [
  {
    title: '一、我们收集的信息',
    body: '为了完成注册、登录和账号安全验证，我们会处理手机号、昵称及登录凭证。你主动进行学生认证时，我们会处理姓名、学号、班级和认证材料；你发布内容时，我们会处理帖子、评论、图片、收藏和互动记录。为了保障服务安全，还可能记录必要的网络请求、操作时间和异常日志。',
  },
  {
    title: '二、设备权限与图片',
    body: '只有在你主动选择头像、发布图片或拍摄照片时，应用才会调用系统相册、图片编辑或相机能力。你可以取消选择或在系统设置中管理权限；拒绝相关权限不会影响浏览、点赞等基础功能。',
  },
  {
    title: '三、信息使用目的',
    body: '相关信息用于提供校园社区服务、展示个人资料、完成学生身份核验、同步点赞评论消息、处理举报申诉、保障账号与内容安全，以及改进产品体验。我们不会将个人信息出售给第三方。',
  },
  {
    title: '四、信息共享与披露',
    body: '除获得你的单独同意、为实现你主动使用的服务所必需，或法律法规、司法及行政机关依法要求外，我们不会向无关第三方提供你的个人信息。公开发布的昵称、头像、帖子和评论会被其他社区用户看到。',
  },
  {
    title: '五、保存与安全',
    body: '我们仅在实现服务目的所需期限内保存信息，并采取访问控制、权限隔离和传输保护等措施。请勿在帖子或评论中公开身份证号、银行卡号、住址等敏感信息。',
  },
  {
    title: '六、你的权利',
    body: '你可以在“我的”页面查看和修改个人资料、管理消息提醒、查看收藏，并可在“账号设置”中修改密码或申请注销账号。注销后将按服务规则处理账号及相关数据，法律法规要求保留的除外。',
  },
  {
    title: '七、未成年人保护',
    body: '若你未满十八周岁，应在监护人指导下阅读并同意本政策。我们不会以诱导方式收集与校园社区服务无关的未成年人信息。',
  },
  {
    title: '八、政策更新与联系',
    body: '政策发生重要变化时，我们会通过应用内公告或显著提示告知。对个人信息处理有疑问或需要行使相关权利，可通过校园社区运营反馈渠道联系我们。',
  },
];

const AGREEMENT_SECTIONS: LegalSection[] = [
  {
    title: '一、服务范围',
    body: '沈大社区为校园成员提供信息交流、内容发布、校园工具和消息互动等服务。部分功能可能要求完成手机号注册、邀请码验证或学生身份认证。',
  },
  {
    title: '二、账号使用',
    body: '你应提供真实、准确、合法的信息并妥善保管账号凭证。不得转让、出借账号，不得冒用他人身份或利用账号从事违法违规活动。',
  },
  {
    title: '三、社区内容规范',
    body: '不得发布违法、侵权、欺诈、骚扰、色情、暴力、恶意营销或泄露他人隐私的内容。平台可依据社区规则对违规内容采取限制展示、删除、禁言或封禁等措施，并提供举报和申诉渠道。',
  },
  {
    title: '四、用户内容与责任',
    body: '你应确保发布内容拥有合法权利，并对内容真实性和合法性负责。引用他人作品时应尊重著作权、署名权及其他合法权益。',
  },
  {
    title: '五、服务调整',
    body: '我们可能根据运营、安全或合规要求调整功能。发生重大变更、暂停或终止服务时，将尽可能通过应用内公告提前说明。',
  },
  {
    title: '六、协议更新',
    body: '本协议更新后会展示新的生效日期。继续使用相关服务前，我们可能再次征求你的确认。',
  },
];

/** 用户协议与隐私政策的统一阅读页。 */
@Component
export struct LegalDocumentPage {
  @Consume('navStack') navStack: NavPathStack;
  @Prop documentType: string = 'privacy';

  private isPrivacy(): boolean {
    return this.documentType !== 'agreement';
  }

  private title(): string {
    return this.isPrivacy() ? '隐私政策' : '用户协议';
  }

  private sections(): LegalSection[] {
    return this.isPrivacy() ? PRIVACY_SECTIONS : AGREEMENT_SECTIONS;
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: this.title(),
          onBack: () => {
            this.navStack.pop();
          }
        })

        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 6 }) {
              Text(this.title())
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
              Text('更新日期：2026年8月30日 · 生效日期：2026年8月30日')
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Text(this.isPrivacy()
              ? '沈大社区重视并保护你的个人信息。请在使用服务前仔细阅读本政策，尤其是涉及学生认证材料、图片权限和账号注销的内容。'
              : '欢迎使用沈大社区。请在注册或使用服务前仔细阅读本协议；完成勾选并继续使用，即表示你理解并同意相关约定。')
              .fontSize(14)
              .lineHeight(23)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
              .padding(16)
              .backgroundColor('#EDF3FF')
              .borderRadius(12)

            ForEach(this.sections(), (section: LegalSection) => {
              Column({ space: 8 }) {
                Text(section.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .width('100%')
                Text(section.body)
                  .fontSize(14)
                  .lineHeight(23)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }, (section: LegalSection) => section.title)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 30 })
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
