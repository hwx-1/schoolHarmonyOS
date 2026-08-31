import { AppColors, AppConfig } from '../constants/AppConfig';
import { LegalDocumentParam } from '../model/Types';

/** 关于页：集中展示版本、产品说明与合规入口。 */
@Component
export struct AboutPage {
  @Consume('navStack') navStack: NavPathStack;

  private openPrivacy(): void {
    const param: LegalDocumentParam = { type: 'privacy' };
    this.navStack.pushPath({ name: 'LegalDocument', param: param });
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('‹')
            .fontSize(26)
            .fontColor(AppColors.TEXT_PRIMARY)
            .padding({ right: 12 })
            .onClick(() => this.navStack.pop())
          Text('关于沈大社区')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 12, bottom: 8 })

        Scroll() {
          Column({ space: 18 }) {
            Column({ space: 10 }) {
              Image($r('app.media.app_icon'))
                .width(76)
                .height(76)
                .borderRadius(18)
              Text('沈大社区')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
              Text(`版本 ${AppConfig.APP_VERSION}（Build ${AppConfig.BUILD_VERSION}）`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
              Text('面向沈阳大学校园成员的信息交流与校园服务平台。')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ top: 28, bottom: 20 })

            Column() {
              this.InfoRow('当前版本', AppConfig.APP_VERSION)
              Divider().margin({ left: 16, right: 16 }).color(AppColors.DIVIDER)
              this.InfoRow('构建版本', AppConfig.BUILD_VERSION)
              Divider().margin({ left: 16, right: 16 }).color(AppColors.DIVIDER)
              Row() {
                Text('隐私政策')
                  .fontSize(15)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Blank()
                Text('›')
                  .fontSize(18)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .width('100%')
              .padding(16)
              .onClick(() => this.openPrivacy())
            }
            .width('100%')
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(14)

            Text('Copyright © 2026 沈大社区')
              .fontSize(11)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }

  @Builder
  private InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColors.TEXT_PRIMARY)
      Blank()
      Text(value)
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(16)
  }
}
