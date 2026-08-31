import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { Session } from '../service/Session';
import { NotificationSync } from '../service/NotificationSync';
import { AppColors } from '../constants/AppConfig';
import { LegalDocumentParam, RegisterBody } from '../model/Types';
import { LegalConsent } from '../components/common/LegalConsent';

@Component
export struct RegisterPage {
  @Consume('navStack') navStack: NavPathStack;
  @State phone: string = '';
  @State code: string = '';
  @State password: string = '';
  @State nickname: string = '';
  @State inviteCode: string = '';
  @State sending: boolean = false;
  @State submitting: boolean = false;
  @State countdown: number = 0;
  @State devCodeTip: string = '';
  @StorageLink('xsnbb_privacy_agreed') agreed: boolean = false;

  private canSendCode(): boolean {
    return this.phone.length === 11 && !this.sending && this.countdown === 0;
  }

  private canSubmit(): boolean {
    return this.phone.length === 11
      && this.code.length >= 4
      && this.password.length >= 6
      && this.nickname.trim().length > 0
      && this.inviteCode.trim().length > 0
      && this.agreed
      && !this.submitting;
  }

  private openLegalDocument(type: string): void {
    const param: LegalDocumentParam = { type: type };
    this.navStack.pushPath({ name: 'LegalDocument', param: param });
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private startCountdown(): void {
    this.countdown = 60;
    const timer = setInterval(() => {
      this.countdown = this.countdown - 1;
      if (this.countdown <= 0) {
        clearInterval(timer);
      }
    }, 1000);
  }

  private async handleSendCode(): Promise<void> {
    if (!this.canSendCode()) {
      return;
    }
    this.sending = true;
    try {
      const resp = await Api.smsCode(this.phone);
      this.startCountdown();
      // 开发模式：真实短信未接入，验证码随响应下发并明确标注
      this.devCodeTip = resp.dev_mode && resp.dev_code
        ? `开发模式验证码：${resp.dev_code}`
        : '验证码已发送，请注意查收';
      this.toast('验证码已下发');
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '发送失败，请稍后重试');
    } finally {
      this.sending = false;
    }
  }

  private async handleRegister(): Promise<void> {
    if (!this.agreed) {
      this.toast('请先阅读并同意《用户协议》和《隐私政策》');
      return;
    }
    if (!this.canSubmit()) {
      this.toast('请完整填写注册信息');
      return;
    }
    this.submitting = true;
    try {
      const body: RegisterBody = {
        phone: this.phone,
        code: this.code,
        password: this.password,
        nickname: this.nickname.trim(),
        invite_code: this.inviteCode.trim(),
      };
      const resp = await Api.register(body);
      Session.applyAccount(resp.account);
      NotificationSync.syncNow();
      this.toast('注册成功，欢迎加入沈大社区');
      this.navStack.replacePath({ name: 'Tabs' });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '注册失败，请稍后重试');
    } finally {
      this.submitting = false;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Row() {
          Text('‹')
            .fontSize(28)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .onClick(() => {
              this.navStack.pop();
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)

          TextInput({ placeholder: '手机号', text: $$this.phone })
          .type(InputType.PhoneNumber)
          .maxLength(11)
          .height(48)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          Row({ space: 10 }) {
          TextInput({ placeholder: '短信验证码', text: $$this.code })
            .type(InputType.Number)
            .maxLength(6)
            .height(48)
            .layoutWeight(1)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(10)
          Button(this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
            .height(48)
            .fontSize(13)
            .backgroundColor(this.canSendCode() ? AppColors.PRIMARY : '#9AB6EA')
            .enabled(this.canSendCode())
            .onClick(() => {
              this.handleSendCode();
            })
          }

          if (this.devCodeTip.length > 0) {
            Text(this.devCodeTip)
            .fontSize(12)
            .fontColor(AppColors.ORANGE)
            .width('100%')
          }

          TextInput({ placeholder: '密码（至少 6 位）', text: $$this.password })
          .type(InputType.Password)
          .height(48)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          TextInput({ placeholder: '昵称', text: $$this.nickname })
          .maxLength(16)
          .height(48)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          TextInput({ placeholder: '邀请码（内测默认 xsnbb-test）', text: $$this.inviteCode })
          .height(48)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          LegalConsent({
            agreed: this.$agreed,
            onOpenAgreement: () => this.openLegalDocument('agreement'),
            onOpenPrivacy: () => this.openLegalDocument('privacy')
          })

          Button(this.submitting ? '注册中…' : '注册并登录')
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor(this.canSubmit() ? AppColors.PRIMARY : '#9AB6EA')
          .onClick(() => {
            this.handleRegister();
          })
        }
        .width('100%')
        .padding({ left: 28, right: 28, top: 32, bottom: 32 })
      }
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
