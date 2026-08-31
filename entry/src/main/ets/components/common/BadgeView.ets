import { AppColors } from '../../constants/AppConfig';

/** 认证徽标：红=官方，蓝=认证机构，绿=管理员发布。 */
@Component
export struct BadgeView {
  @Prop badge: string = 'org';

  private badgeColor(): string {
    if (this.badge === 'official') {
      return AppColors.DANGER;
    }
    if (this.badge === 'admin') {
      return '#0A8A4D';
    }
    return AppColors.PRIMARY;
  }

  private badgeLabel(): string {
    if (this.badge === 'official') {
      return '官方';
    }
    if (this.badge === 'admin') {
      return '管理员';
    }
    return '认证';
  }

  build() {
    Row({ space: 3 }) {
      Stack() {
        Text('✓')
          .fontSize(8)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(12)
      .height(12)
      .borderRadius(6)
      .backgroundColor(this.badgeColor())

      Text(this.badgeLabel())
        .fontSize(10)
        .fontColor(this.badgeColor())
    }
  }
}
