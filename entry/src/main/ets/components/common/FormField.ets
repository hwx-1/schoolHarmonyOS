import { AppColors } from '../../constants/AppConfig';

/** 表单输入行：标题 + 输入框，@Link 双向绑定值。 */
@Component
export struct FormField {
  @Prop label: string = '';
  @Prop placeholder: string = '';
  @Link value: string;
  @Prop inputType: InputType = InputType.Normal;

  build() {
    Column({ space: 6 }) {
      Text(this.label)
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
      TextInput({ placeholder: this.placeholder, text: $$this.value })
        .type(this.inputType)
        .width('100%')
        .height(46)
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(10)
    }
    .width('100%')
  }
}
