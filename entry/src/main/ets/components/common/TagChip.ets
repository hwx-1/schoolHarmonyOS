import { AppColors } from '../../constants/AppConfig';

/** 话题标签胶囊。 */
@Component
export struct TagChip {
  @Prop text: string = '';
  onTap: (tag: string) => void = () => {};

  build() {
    Text(`# ${this.text}`)
      .fontSize(12)
      .fontColor(AppColors.PRIMARY)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#1A2E6BE6')
      .borderRadius(12)
      .onClick(() => this.onTap(this.text))
  }
}
