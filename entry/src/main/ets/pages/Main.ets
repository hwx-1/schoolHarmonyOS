import { Session } from '../service/Session';
import { AppColors } from '../constants/AppConfig';
import { PageMap } from './PageMap';

/**
 * 应用唯一入口页：Navigation 根容器。
 * 所有页面均为 NavDestination，由 NavPathStack 统一调度，
 * 替代已废弃的 router 页面路由。
 */
@Entry
@Component
struct Main {
  @Provide('navStack') navStack: NavPathStack = new NavPathStack();
  @State @Watch('onReadyChange') ready: boolean = false;
  private initialRoute: string = 'Login';

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    const loggedIn = await Session.restore();
    this.initialRoute = loggedIn ? 'Tabs' : 'Login';
    this.ready = true;
  }

  onReadyChange(): void {
    if (this.ready) {
      this.navStack.replacePath({ name: this.initialRoute });
    }
  }

  build() {
    Navigation(this.navStack) {
      Column() {
        if (!this.ready) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(AppColors.PRIMARY)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .navDestination(PageMap)
    .hideTitleBar(true)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}
