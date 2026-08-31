import { AppColors } from '../../constants/AppConfig';

/**
 * 微信风格顶部导航栏：标题始终居中，左侧为返回/文字操作，右侧为可选文字或实心按钮。
 * 纯参数驱动（不使用 @BuilderParam），长标题自动省略且不与两侧操作区重叠。
 */
@Component
export struct NavBar {
  title: string = '';
  /** 标题下方的副标题，如「今日剩余 N 次」。 */
  subtitle: string = '';
  /** 标题右侧的小标签，如私信页的「自由聊」。 */
  titleTag: string = '';
  showBack: boolean = true;
  onBack: () => void = () => {};
  /** 左侧文字操作（设置后替代返回箭头），如「取消」。 */
  leftText: string = '';
  onLeft: () => void = () => {};
  /** 右侧文字操作，如「全部已读」「保存」。 */
  rightText: string = '';
  rightFontSize: number = 14;
  rightColor: ResourceColor = AppColors.PRIMARY;
  rightEnabled: boolean = true;
  onRight: () => void = () => {};
  /** 右侧实心按钮（优先级高于 rightText），如「+ 新会话」。 */
  rightButtonText: string = '';
  onRightButton: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 居中标题层：左右留白，避免与两侧操作区重叠
      Column({ space: 2 }) {
        Row({ space: 8 }) {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.titleTag.length > 0) {
            Text(this.titleTag)
              .fontSize(10)
              .fontColor('#0A8A4D')
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor('#140A8A4D')
              .borderRadius(4)
          }
        }

        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 72, right: 72 })

      // 左右操作区
      Row() {
        if (this.leftText.length > 0) {
          Text(this.leftText)
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .padding({ left: 4, right: 8, top: 4, bottom: 4 })
            .onClick(() => this.onLeft())
        } else if (this.showBack) {
          Text('‹')
            .fontSize(28)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .padding({ left: 4, right: 12, top: 2, bottom: 2 })
            .onClick(() => this.onBack())
        }
        Blank()
        if (this.rightButtonText.length > 0) {
          Button(this.rightButtonText)
            .height(32)
            .fontSize(13)
            .backgroundColor(AppColors.PRIMARY)
            .onClick(() => this.onRightButton())
        } else if (this.rightText.length > 0) {
          Text(this.rightText)
            .fontSize(this.rightFontSize)
            .fontColor(this.rightEnabled ? this.rightColor : AppColors.TEXT_SECONDARY)
            .padding({ left: 8, right: 4, top: 4, bottom: 4 })
            .onClick(() => this.onRight())
        }
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ left: 12, right: 16, top: 6, bottom: 6 })
  }
}
