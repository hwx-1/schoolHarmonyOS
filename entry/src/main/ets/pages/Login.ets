import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { Session } from '../service/Session';
import { NotificationSync } from '../service/NotificationSync';
import { AppColors } from '../constants/AppConfig';
import { LegalDocumentParam } from '../model/Types';
import { LegalConsent } from '../components/common/LegalConsent';

@Component
export struct LoginPage {
  @Consume('navStack') navStack: NavPathStack;
  @State phone: string = '';
  @State password: string = '';
  @StorageLink('xsnbb_privacy_agreed') agreed: boolean = false;
  @State submitting: boolean = false;

  private formReady(): boolean {
    return this.phone.length === 11 && this.password.length >= 6;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private openLegalDocument(type: string): void {
    const param: LegalDocumentParam = { type: type };
    this.navStack.pushPath({ name: 'LegalDocument', param: param });
  }

  private async handleLogin(): Promise<void> {
    if (this.submitting) {
      return;
    }
    // 逐项校验并给出明确反馈，避免"点了没反应"
    if (this.phone.length !== 11) {
      this.toast('请输入 11 位手机号');
      return;
    }
    if (this.password.length < 6) {
      this.toast('密码至少 6 位');
      return;
    }
    if (!this.agreed) {
      this.toast('请先阅读并同意《用户协议》和《隐私政策》');
      return;
    }
    this.submitting = true;
    try {
      const resp = await Api.login(this.phone, this.password);
      Session.applyAccount(resp.account);
      NotificationSync.syncNow();
      this.toast(`欢迎回来，${resp.account.nickname}`);
      this.navStack.replacePath({ name: 'Tabs' });
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '登录失败，请稍后重试');
    } finally {
      this.submitting = false;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // Logo 区
          Column({ space: 0 }) {
            Stack() {
              Text('沈')
                .fontSize(32)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(76)
            .height(76)
            .borderRadius(22)
            .linearGradient({
              direction: GradientDirection.RightBottom,
              colors: [[AppColors.PRIMARY, 0.0], ['#5B8DEF', 1.0]],
            })
            .shadow({ radius: 16, color: '#332E6BE6', offsetY: 6 })

            Text('沈大社区')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
              .margin({ top: 18 })
            Text('沈阳大学校园社区')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: 6 })
          }
          .margin({ top: 72, bottom: 40 })

          // 输入区
          TextInput({ placeholder: '手机号', text: $$this.phone })
            .type(InputType.PhoneNumber)
            .maxLength(11)
            .height(52)
            .padding({ left: 16, right: 16 })
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(12)

          TextInput({ placeholder: '密码（至少 6 位）', text: $$this.password })
            .type(InputType.Password)
            .showPasswordIcon(true)
            .height(52)
            .padding({ left: 16, right: 16 })
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(12)
            .margin({ top: 14 })

          LegalConsent({
            agreed: this.$agreed,
            onOpenAgreement: () => this.openLegalDocument('agreement'),
            onOpenPrivacy: () => this.openLegalDocument('privacy')
          })
          .margin({ top: 18 })

          // 登录按钮：始终可点，未通过校验时点击给出具体提示
          Button() {
            Row({ space: 8 }) {
              if (this.submitting) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(Color.White)
              }
              Text(this.submitting ? '登录中…' : '登 录')
                .fontSize(17)
                .fontColor(Color.White)
            }
          }
          .width('100%')
          .height(50)
          .borderRadius(25)
          .backgroundColor(this.formReady() && this.agreed ? AppColors.PRIMARY : '#9AB6EA')
          .margin({ top: 28 })
          .onClick(() => {
            this.handleLogin();
          })

          Row({ space: 4 }) {
            Text('还没有账号？')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
            Text('立即注册')
              .fontSize(13)
              .fontColor(AppColors.PRIMARY)
              .onClick(() => {
                this.navStack.pushPath({ name: 'Register' });
              })
          }
          .margin({ top: 22, bottom: 40 })
        }
        .width('100%')
        .padding({ left: 28, right: 28 })
        .alignItems(HorizontalAlign.Center)
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
