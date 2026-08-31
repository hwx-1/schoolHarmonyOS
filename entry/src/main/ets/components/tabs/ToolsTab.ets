import { common } from '@kit.AbilityKit';
import { Api } from '../../service/Api';
import { CampusTool } from '../../model/Types';
import { AppColors } from '../../constants/AppConfig';
import { LoadingView } from '../common/LoadingView';
import { EmptyState } from '../common/EmptyState';
import { NavBar } from '../common/NavBar';

/** 百宝箱 Tab：AI 助手入口横幅 + 全部校园工具（4 列网格）。 */
@Component
export struct ToolsTab {
  @Consume('navStack') navStack: NavPathStack;
  @State items: CampusTool[] = [];
  @State loading: boolean = true;
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async load(): Promise<void> {
    try {
      const resp = await Api.listTools();
      this.items = resp.items
        .filter((item: CampusTool) => item.enabled)
        .sort((a: CampusTool, b: CampusTool) => b.weight - a.weight);
    } catch {
    }
    this.loading = false;
    this.refreshing = false;
  }

  private async openTool(tool: CampusTool): Promise<void> {
    if (!tool.url || tool.url.length === 0) {
      this.toast('该工具暂未开放链接');
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await context.openLink(tool.url);
    } catch {
      this.toast('无法打开该链接');
    }
  }

  private toolIcon(tool: CampusTool): string {
    if (tool.icon.length > 0) {
      return tool.icon;
    }
    return tool.type === 'link' ? '🔗' : '🧰';
  }

  build() {
    Column({ space: 12 }) {
      // 顶部：与消息页一致的居中标题栏
      NavBar({ title: '百宝箱', showBack: false })

      // AI 助手入口横幅：AI 是百宝箱的一部分
      Row({ space: 12 }) {
        Image($r('app.media.ic_sparkle'))
          .width(26)
          .height(26)
          .fillColor(Color.White)
        Column({ space: 2 }) {
          Text('AI 校园助手')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
          Text('课表、图书馆、校历，问它就知道')
            .fontSize(11)
            .fontColor('#CCFFFFFF')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('›')
          .fontSize(20)
          .fontColor(Color.White)
      }
      .width('100%')
      .padding(16)
      .borderRadius(14)
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [[AppColors.PRIMARY, 0.0], ['#5B8DEF', 1.0]],
      })
      .margin({ left: 12, right: 12, top: 12 })
      .onClick(() => {
        this.navStack.pushPath({ name: 'AI' });
      })

      if (this.loading) {
        LoadingView()
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          Grid() {
            ForEach(this.items, (tool: CampusTool) => {
              GridItem() {
                Column({ space: 8 }) {
                  Text(this.toolIcon(tool))
                    .fontSize(26)
                  Text(tool.name)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding({ top: 16, bottom: 16, left: 4, right: 4 })
                .backgroundColor(AppColors.CARD_BG)
                .borderRadius(12)
                .onClick(() => {
                  this.openTool(tool);
                })
              }
            }, (tool: CampusTool) => `${tool.id}`)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .width('100%')
          .padding({ left: 12, right: 12 })
        }
        .onRefreshing(() => {
          this.refreshing = true;
          this.load();
        })
        .layoutWeight(1)

        if (this.items.length === 0) {
          EmptyState({ title: '暂无可用工具' })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}
