import { AppColors } from '../constants/AppConfig';
import { NotificationSync } from '../service/NotificationSync';
import { NavBar } from '../components/common/NavBar';

/** 本机消息提醒设置，偏好由 PersistentStorage 持久化。 */
@Component
export struct NotificationSettingsPage {
  @Consume('navStack') navStack: NavPathStack;
  @StorageLink('xsnbb_in_app_notification_enabled') inAppEnabled: boolean = true;
  @StorageLink('xsnbb_notification_badge_enabled') badgeEnabled: boolean = true;
  @StorageLink('xsnbb_notification_auto_sync_enabled') autoSyncEnabled: boolean = true;

  private updateAutoSync(enabled: boolean): void {
    this.autoSyncEnabled = enabled;
    if (enabled) {
      NotificationSync.syncNow();
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '消息通知设置',
          onBack: () => {
            this.navStack.pop();
          }
        })

        Scroll() {
          Column({ space: 14 }) {
            Column() {
              this.SwitchRow(
                '应用内新消息提醒',
                '前台使用时以轻提示告知新的点赞、评论和系统消息',
                this.inAppEnabled,
                (enabled: boolean) => { this.inAppEnabled = enabled; },
              )
              Divider().margin({ left: 16, right: 16 }).color(AppColors.DIVIDER)
              this.SwitchRow(
                '底栏未读气泡',
                '在“消息”图标右上角显示未读数量',
                this.badgeEnabled,
                (enabled: boolean) => { this.badgeEnabled = enabled; },
              )
              Divider().margin({ left: 16, right: 16 }).color(AppColors.DIVIDER)
              this.SwitchRow(
                '自动同步消息',
                '应用处于前台时定期拉取新消息；关闭后进入消息页仍可刷新',
                this.autoSyncEnabled,
                (enabled: boolean) => this.updateAutoSync(enabled),
              )
            }
            .width('100%')
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(14)

            Text('以上设置只影响当前设备，不会删除消息。系统级通知权限仍可在设备“设置”中管理。')
              .fontSize(12)
              .lineHeight(19)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
              .padding({ left: 4, right: 4 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12 })
        }
        .align(Alignment.Top)
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }

  @Builder
  private SwitchRow(title: string, desc: string, enabled: boolean, onChange: (enabled: boolean) => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(15)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(desc)
          .fontSize(11)
          .lineHeight(17)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(AppColors.PRIMARY)
        .onChange((value: boolean) => onChange(value))
    }
    .width('100%')
    .padding(16)
  }
}
