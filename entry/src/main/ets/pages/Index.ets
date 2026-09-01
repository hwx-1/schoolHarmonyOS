import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColors } from '../constants/AppConfig';
import { HomeTab } from '../components/tabs/HomeTab';
import { MessagesTab } from '../components/tabs/MessagesTab';
import { ToolsTab } from '../components/tabs/ToolsTab';
import { MineTab } from '../components/tabs/MineTab';
import { Api } from '../service/Api';
import { AppState } from '../service/AppState';

const TAG = 'TabsPage';
const DOMAIN = 0x0001;

/** 主界面：四个 Tab + 发布入口，作为 NavDestination 由 Main 调度。 */
@Component
export struct TabsPage {
  @Consume('navStack') navStack: NavPathStack;
  @State currentTab: number = 0;
  @StorageProp('xsnbb_unread_count') @Watch('onUnreadCountChange') unreadCount: number = 0;
  @StorageProp('xsnbb_direct_unread_count') directUnreadCount: number = 0;
  @StorageProp('xsnbb_in_app_notification_enabled') inAppNotificationEnabled: boolean = true;
  @StorageProp('xsnbb_notification_badge_enabled') notificationBadgeEnabled: boolean = true;
  private tabsController: TabsController = new TabsController();
  private observedUnreadCount: number = -1;
  private hasUnreadBaseline: boolean = false;

  aboutToAppear(): void {
    AppState.requestPostRefresh();
    this.refreshUnread();
  }

  private onUnreadCountChange(): void {
    const previous = this.observedUnreadCount;
    this.observedUnreadCount = this.unreadCount;
    // 登录进入后的首次同步只建立未读基线，由底栏数字冒泡呈现，不弹 Toast；
    // 之后在前台收到新消息时才轻提示。
    if (!this.hasUnreadBaseline) {
      this.hasUnreadBaseline = true;
      return;
    }
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
    } catch (e) {
      // 未读数刷新失败不阻塞主界面，但保留日志便于联调定位
      hilog.error(DOMAIN, TAG, `refreshUnread failed: ${(e as Error).message}`);
    }
    try {
      const response = await Api.listDirectConversations();
      AppState.setDirectUnreadCount(response.unread);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `refresh direct unread failed: ${(e as Error).message}`);
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: $$this.currentTab }) {
          TabContent() {
            HomeTab()
          }
          .tabBar(this.TabItem({ icon: $r('app.media.ic_home'), label: '首页', index: 0, badge: 0 }))

          TabContent() {
            ToolsTab()
          }
          .tabBar(this.TabItem({ icon: $r('app.media.ic_grid'), label: '百宝箱', index: 1, badge: 0 }))

          TabContent() {
            MessagesTab()
          }
          .tabBar(this.TabItem({
            icon: $r('app.media.ic_bell'),
            label: '消息',
            index: 2,
            badge: this.notificationBadgeEnabled ? this.unreadCount + this.directUnreadCount : 0,
          }))

          TabContent() {
            MineTab()
          }
          .tabBar(this.TabItem({ icon: $r('app.media.ic_user'), label: '我的', index: 3, badge: 0 }))
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

  /**
   * 底栏单个导航项。
   * 注意两点 ArkUI 约束：
   * 1. .tabBar() 只能接收 @Builder，直接传 @Component 构造调用会在重建时崩溃
   *    （class constructor cannot called without 'new'）；
   * 2. @Builder 多个按值参数不会随状态刷新（角标会停留在首次构建的 0），
   *    因此用单个对象字面量参数按引用传递，未读数变化才会驱动角标刷新。
   */
  @Builder
  private TabItem(params: TabItemParams) {
    Column({ space: 1 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image(params.icon)
          .width(20)
          .height(20)
          .fillColor(this.currentTab === params.index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
        if (params.badge > 0) {
          Text(params.badge > 99 ? '99+' : `${params.badge}`)
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .width(params.badge > 99 ? 30 : params.badge > 9 ? 22 : 16)
            .height(16)
            .padding({ left: 4, right: 4 })
            .backgroundColor(AppColors.DANGER)
            .borderRadius(8)
            .border({ width: 1, color: Color.White })
            .position({ x: params.badge > 99 ? 12 : params.badge > 9 ? 20 : 26, y: -5 })
        }
      }
      .width(42)
      .height(22)
      Text(params.label)
        .fontSize(10)
        .fontColor(this.currentTab === params.index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}

/** 底栏导航项参数。必须以单个对象字面量传给 @Builder：按引用传递，状态变化才能驱动刷新。 */
interface TabItemParams {
  icon: Resource;
  label: string;
  index: number;
  badge: number;
}
