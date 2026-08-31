import { AppColors } from '../../constants/AppConfig';

/** 居中加载指示。 */
@Component
export struct LoadingView {
  @Prop text: string = '加载中…';

  build() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(AppColors.PRIMARY)
      Text(this.text)
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(48)
    .justifyContent(FlexAlign.Center)
  }
}
