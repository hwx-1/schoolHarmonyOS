import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { AppColors } from '../constants/AppConfig';
import { NavBar } from '../components/common/NavBar';

/** 通过已绑定手机号和短信验证码重置密码。 */
@Component
export struct ForgotPasswordPage {
  @Consume('navStack') navStack: NavPathStack;
  @State phone: string = '';
  @State code: string = '';
  @State password: string = '';
  @State sending: boolean = false;
  @State submitting: boolean = false;
  @State countdown: number = 0;
  @State devCodeTip: string = '';

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // 系统提示不可用时不影响业务请求。
    }
  }

  private startCountdown(): void {
    this.countdown = 60;
    const timer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        clearInterval(timer);
      }
    }, 1000);
  }

  private async sendCode(): Promise<void> {
    if (this.phone.length !== 11 || this.sending || this.countdown > 0) {
      this.toast('请先填写 11 位手机号');
      return;
    }
    this.sending = true;
    try {
      const resp = await Api.smsCode(this.phone, 'reset');
      this.devCodeTip = resp.dev_mode && resp.dev_code ? `开发模式验证码：${resp.dev_code}` : '验证码已发送';
      this.startCountdown();
      this.toast('验证码已发送');
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '验证码发送失败');
    } finally {
      this.sending = false;
    }
  }

  private async submit(): Promise<void> {
    if (this.submitting || this.phone.length !== 11 || this.code.length < 4 || this.password.length < 8) {
      this.toast('请完整填写信息，新密码至少 8 位');
      return;
    }
    this.submitting = true;
    try {
      await Api.resetPassword(this.phone, this.code, this.password);
      this.toast('密码重置成功，请重新登录');
      this.navStack.replacePath({ name: 'Login' });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '密码重置失败');
    } finally {
      this.submitting = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({ title: '重置密码', onBack: () => this.navStack.pop() })
        Scroll() {
          Column({ space: 14 }) {
            Text('验证码将发送至已绑定手机号')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
            TextInput({ placeholder: '手机号', text: $$this.phone })
              .type(InputType.PhoneNumber).maxLength(11).height(48)
              .backgroundColor(AppColors.CARD_BG).borderRadius(10)
            Row({ space: 10 }) {
              TextInput({ placeholder: '短信验证码', text: $$this.code })
                .type(InputType.Number).maxLength(6).height(48).layoutWeight(1)
                .backgroundColor(AppColors.CARD_BG).borderRadius(10)
              Button(this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
                .height(48).fontSize(13).backgroundColor(AppColors.PRIMARY)
                .enabled(this.countdown === 0 && !this.sending)
                .onClick(() => this.sendCode())
            }
            if (this.devCodeTip.length > 0) {
              Text(this.devCodeTip).fontSize(12).fontColor(AppColors.ORANGE).width('100%')
            }
            TextInput({ placeholder: '新密码（至少 8 位）', text: $$this.password })
              .type(InputType.Password).height(48)
              .backgroundColor(AppColors.CARD_BG).borderRadius(10)
            Button(this.submitting ? '处理中…' : '确认重置')
              .width('100%').height(48).backgroundColor(AppColors.PRIMARY)
              .enabled(!this.submitting)
              .onClick(() => this.submit())
          }
          .width('100%').padding(20)
        }
        .layoutWeight(1)
      }
      .width('100%').height('100%').backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
