import { AppColors } from '../../constants/AppConfig';

/** 空态 / 错误态占位，带可选重试按钮。 */
@Component
export struct EmptyState {
  @Prop title: string = '暂无内容';
  @Prop desc: string = '';
  @Prop actionText: string = '';
  onAction: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text('🍃')
        .fontSize(44)
      Text(this.title)
        .fontSize(16)
        .fontColor(AppColors.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)
      if (this.desc.length > 0) {
        Text(this.desc)
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
      }
      if (this.actionText.length > 0) {
        Button(this.actionText)
          .fontSize(14)
          .height(36)
          .backgroundColor(AppColors.PRIMARY)
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .padding({ top: 64, bottom: 64, left: 32, right: 32 })
    .justifyContent(FlexAlign.Center)
  }
}
