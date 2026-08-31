import { AppColors } from '../../constants/AppConfig';

/** 登录与注册共用的协议确认组件。 */
@Component
export struct LegalConsent {
  @Link agreed: boolean;
  onOpenAgreement: () => void = () => {};
  onOpenPrivacy: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Stack() {
        if (this.agreed) {
          Text('✓')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
      }
      .width(20)
      .height(20)
      .borderRadius(10)
      .backgroundColor(this.agreed ? AppColors.PRIMARY : '#00000000')
      .border({
        width: 1.5,
        color: this.agreed ? AppColors.PRIMARY : '#C4C9D4',
      })
      .onClick(() => {
        this.agreed = !this.agreed;
      })

      Text() {
        Span('我已阅读并同意')
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
        Span('《用户协议》')
          .fontSize(12)
          .fontColor(AppColors.PRIMARY)
          .onClick(() => this.onOpenAgreement())
        Span('和')
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
        Span('《隐私政策》')
          .fontSize(12)
          .fontColor(AppColors.PRIMARY)
          .onClick(() => this.onOpenPrivacy())
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
}
