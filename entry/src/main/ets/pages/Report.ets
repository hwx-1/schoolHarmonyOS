import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { AppColors } from '../constants/AppConfig';
import { NavBar } from '../components/common/NavBar';

/** 帖子、评论、用户和私信共用的举报表单。 */
@Component
export struct ReportPage {
  @Consume('navStack') navStack: NavPathStack;
  @Prop targetType: string = '';
  @Prop targetId: number = 0;
  @Prop targetName: string = '';
  @State reason: string = '';
  @State submitting: boolean = false;

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // 系统提示不可用时不影响业务请求。
    }
  }

  private async submit(): Promise<void> {
    const reason = this.reason.trim();
    if (reason.length < 2 || this.submitting) {
      this.toast('请填写举报原因');
      return;
    }
    this.submitting = true;
    try {
      if (this.targetType === 'post') {
        await Api.reportPost(this.targetId, reason);
      } else if (this.targetType === 'comment') {
        await Api.reportComment(this.targetId, reason);
      } else if (this.targetType === 'user') {
        await Api.reportUser(this.targetId, reason);
      } else if (this.targetType === 'dm') {
        await Api.reportDirectConversation(this.targetId, reason);
      } else {
        throw new Error('不支持的举报对象');
      }
      this.toast('举报已提交，平台将尽快处理');
      this.navStack.pop();
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '举报提交失败');
    } finally {
      this.submitting = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '举报',
          showBack: false,
          leftText: '取消',
          onLeft: () => this.navStack.pop(),
          rightText: this.submitting ? '提交中…' : '提交',
          rightEnabled: this.reason.trim().length >= 2 && !this.submitting,
          onRight: () => this.submit()
        })
        Column({ space: 14 }) {
          Text(`举报对象：${this.targetName}`)
            .fontSize(13).fontColor(AppColors.TEXT_SECONDARY).width('100%')
          TextArea({ placeholder: '请描述违规情况（如骚扰、广告、不当内容等）', text: $$this.reason })
            .width('100%').height(160).padding(12)
            .backgroundColor(AppColors.CARD_BG).borderRadius(12)
          Text('举报提交后，相关内容可能进入复核流程。平台不会向被举报人透露举报者身份。')
            .fontSize(12).fontColor(AppColors.TEXT_SECONDARY).width('100%')
        }
        .width('100%').padding(16).layoutWeight(1)
      }
      .width('100%').height('100%').backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
