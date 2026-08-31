import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { Session } from '../service/Session';
import { AppColors, AppConfig } from '../constants/AppConfig';
import { FormField } from '../components/common/FormField';
import { NavBar } from '../components/common/NavBar';

@Component
export struct AccountSettingsPage {
  @Consume('navStack') navStack: NavPathStack;
  @State currentPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State changing: boolean = false;
  @State deleting: boolean = false;

  private canChangePassword(): boolean {
    return this.currentPassword.length >= 6
      && this.newPassword.length >= 6
      && this.newPassword === this.confirmPassword
      && !this.changing;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async changePassword(): Promise<void> {
    if (!this.canChangePassword()) {
      if (this.newPassword !== this.confirmPassword) {
        this.toast('两次输入的新密码不一致');
      }
      return;
    }
    this.changing = true;
    try {
      await Api.changePassword(this.currentPassword, this.newPassword);
      this.toast('密码已修改');
      this.currentPassword = '';
      this.newPassword = '';
      this.confirmPassword = '';
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '修改失败，请稍后重试');
    } finally {
      this.changing = false;
    }
  }

  private confirmDeleteAccount(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '注销账号',
      message: '注销后账号与数据将被删除且不可恢复，确定继续吗？',
      buttons: [
        { text: '取消', color: AppColors.TEXT_SECONDARY },
        { text: '确认注销', color: AppColors.DANGER },
      ],
    }).then((resp) => {
      if (resp.index === 1) {
        this.deleteAccount();
      }
    }).catch(() => {
      // 对话框被取消或系统异常时不影响主流程
    });
  }

  private async deleteAccount(): Promise<void> {
    if (this.deleting) {
      return;
    }
    this.deleting = true;
    try {
      await Api.deleteAccount();
      await Session.logout();
      this.toast('账号已注销');
      this.navStack.replacePath({ name: 'Login' });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '注销失败，请稍后重试');
    } finally {
      this.deleting = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '账号设置',
          onBack: () => {
            this.navStack.pop();
          }
        })

        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 14 }) {
              Text('修改密码')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
              FormField({
                label: '当前密码',
                placeholder: '请输入当前密码',
                value: this.$currentPassword,
                inputType: InputType.Password
              })
              FormField({
                label: '新密码',
                placeholder: '至少 6 位',
                value: this.$newPassword,
                inputType: InputType.Password
              })
              FormField({
                label: '确认新密码',
                placeholder: '再次输入新密码',
                value: this.$confirmPassword,
                inputType: InputType.Password
              })
              Button(this.changing ? '提交中…' : '确认修改')
                .width('100%')
                .height(44)
                .fontSize(14)
                .backgroundColor(this.canChangePassword() ? AppColors.PRIMARY : '#9AB6EA')
                .enabled(this.canChangePassword())
                .onClick(() => {
                  this.changePassword();
                })
            }
            .width('100%')

            Column({ space: 10 }) {
              Text('危险操作')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.DANGER)
                .width('100%')
              Text('注销账号将删除账号、帖子、评论与私信记录，操作不可撤销。')
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%')
              Text(this.deleting ? '注销中…' : '注销账号')
                .fontSize(14)
                .fontColor(AppColors.DANGER)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(12)
                .backgroundColor('#14E5484D')
                .borderRadius(10)
                .onClick(() => {
                  this.confirmDeleteAccount();
                })
            }
            .width('100%')

            Text(`接口地址：${AppConfig.API_BASE_URL}`)
              .fontSize(11)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
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
