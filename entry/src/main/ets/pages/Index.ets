import { AppColors } from '../constants/AppConfig';
import { HomeTab } from '../components/tabs/HomeTab';
import { MessagesTab } from '../components/tabs/MessagesTab';
import { ToolsTab } from '../components/tabs/ToolsTab';
import { MineTab } from '../components/tabs/MineTab';
import { Api } from '../service/Api';
import { AppState } from '../service/AppState';

/** 主界面：四个 Tab + 发布入口，作为 NavDestination 由 Main 调度。 */
@Component
export struct TabsPage {
  @Consume('navStack') navStack: NavPathStack;
  @State currentTab: number = 0;
  @StorageProp('xsnbb_unread_count') @Watch('onUnreadCountChange') unreadCount: number = 0;
  @StorageProp('xsnbb_in_app_notification_enabled') inAppNotificationEnabled: boolean = true;
  @StorageProp('xsnbb_notification_badge_enabled') notificationBadgeEnabled: boolean = true;
  private tabsController: TabsController = new TabsController();
  private observedUnreadCount: number = -1;

  aboutToAppear(): void {
    this.observedUnreadCount = this.unreadCount;
    AppState.requestPostRefresh();
    this.refreshUnread();
  }

  private onUnreadCountChange(): void {
    const previous = this.observedUnreadCount;
    this.observedUnreadCount = this.unreadCount;
    if (this.inAppNotificationEnabled && previous >= 0 && this.unreadCount > previous) {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: `收到 ${this.unreadCount - previous} 条新的互动消息`,
        });
      } catch {
        // Toast 失败不影响底栏未读红点同步
      }
    }
  }

  private async refreshUnread(): Promise<void> {
    try {
      const response = await Api.notifications();
      AppState.setUnreadCount(response.unread);
    } catch {
      // 未读数刷新失败不阻塞主界面
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: $$this.currentTab }) {
          TabContent() {
            HomeTab()
          }
          .tabBar(this.TabItem($r('app.media.ic_home'), '首页', 0, 0))

          TabContent() {
            ToolsTab()
          }
          .tabBar(this.TabItem($r('app.media.ic_grid'), '百宝箱', 1, 0))

          TabContent() {
            MessagesTab()
          }
          .tabBar(this.TabItem(
            $r('app.media.ic_bell'),
            '消息',
            2,
            this.notificationBadgeEnabled ? this.unreadCount : 0,
          ))

          TabContent() {
            MineTab()
          }
          .tabBar(this.TabItem($r('app.media.ic_user'), '我的', 3, 0))
        }
        .barMode(BarMode.Fixed)
        .scrollable(false)
        .barHeight(52)
        .width('100%')
        .height('100%')
        .onChange((index: number) => {
          this.currentTab = index;
          if (index === 0) {
            AppState.requestPostRefresh();
          } else if (index === 2) {
            AppState.requestMessageRefresh();
            this.refreshUnread();
          }
        })

        // 发布按钮
        Stack() {
          Image($r('app.media.ic_add'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
        }
        .width(52)
        .height(52)
        .borderRadius(26)
        .backgroundColor(AppColors.PRIMARY)
        .shadow({ radius: 12, color: '#552E6BE6', offsetY: 4 })
        .margin({ right: 20, bottom: 72 })
        .onClick(() => {
          this.navStack.pushPath({ name: 'Compose' });
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }

  @Builder
  private TabItem(icon: Resource, label: string, index: number, badge: number) {
    Column({ space: 1 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image(icon)
          .width(20)
          .height(20)
          .fillColor(this.currentTab === index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
        if (badge > 0) {
          Text(badge > 99 ? '99+' : `${badge}`)
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .width(badge > 99 ? 30 : badge > 9 ? 22 : 16)
            .height(16)
            .padding({ left: 4, right: 4 })
            .backgroundColor(AppColors.DANGER)
            .borderRadius(8)
            .border({ width: 1, color: Color.White })
            .position({ x: badge > 99 ? 12 : badge > 9 ? 20 : 26, y: -5 })
        }
      }
      .width(42)
      .height(22)
      Text(label)
        .fontSize(10)
        .fontColor(this.currentTab === index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
