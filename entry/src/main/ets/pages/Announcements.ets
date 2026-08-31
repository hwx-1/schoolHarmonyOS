import { Api } from '../service/Api';
import { Announcement } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { AnnouncementCard } from '../components/business/AnnouncementCard';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';

@Component
export struct AnnouncementsPage {
  @Consume('navStack') navStack: NavPathStack;
  @State items: Announcement[] = [];
  @State loading: boolean = true;
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const resp = await Api.listAnnouncements();
      this.items = resp.items.filter((item: Announcement) => item.published);
    } catch {
    }
    this.loading = false;
    this.refreshing = false;
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('‹')
            .fontSize(26)
            .fontColor(AppColors.TEXT_PRIMARY)
            .padding({ right: 12 })
            .onClick(() => {
              this.navStack.pop();
            })
          Text('校园公告')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 12, bottom: 8 })

        if (this.loading) {
          LoadingView()
        } else {
          Refresh({ refreshing: $$this.refreshing }) {
            List({ space: 12 }) {
              ForEach(this.items, (item: Announcement) => {
                ListItem() {
                  AnnouncementCard({ announcement: item })
                }
              }, (item: Announcement) => `${item.id}`)
              if (this.items.length === 0) {
                ListItem() {
                  EmptyState({ title: '暂无公告' })
                }
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12 })
          }
          .onRefreshing(() => {
            this.refreshing = true;
            this.load();
          })
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
