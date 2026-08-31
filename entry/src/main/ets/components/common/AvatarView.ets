import { absoluteMediaUrl } from '../../service/Http';
import { AppColors } from '../../constants/AppConfig';

/** 圆形头像：有图显示图，无图显示昵称首字。 */
@Component
export struct AvatarView {
  @Prop avatar: string = '';
  @Prop nickname: string = '';
  @Prop diameter: number = 40;

  private initial(): string {
    return this.nickname.length > 0 ? this.nickname.substring(0, 1) : '客';
  }

  private url(): string {
    return absoluteMediaUrl(this.avatar);
  }

  build() {
    if (this.url().length > 0) {
      Image(this.url())
        .width(this.diameter)
        .height(this.diameter)
        .borderRadius(this.diameter / 2)
        .objectFit(ImageFit.Cover)
    } else {
      Stack() {
        Text(this.initial())
          .fontSize(this.diameter * 0.42)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
      }
      .width(this.diameter)
      .height(this.diameter)
      .borderRadius(this.diameter / 2)
      .backgroundColor(AppColors.PRIMARY)
    }
  }
}
