import { Api } from '../service/Api';
import { ApiError } from '../service/Http';
import { Appeal } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { NavBar } from '../components/common/NavBar';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { TimeUtil } from '../utils/TimeUtil';

/** 我的申诉：查看历史处理结果，也可从处罚通知携带 punishmentId 直接提交。 */
@Component
export struct AppealsPage {
  @Consume('navStack') navStack: NavPathStack;
  @Prop punishmentId: number = 0;
  @State items: Appeal[] = [];
  @State reason: string = '';
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State loadError: string = '';

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
    this.loadError = '';
    try {
      const resp = await Api.myAppeals();
      this.items = resp.items;
      if (this.items.some((item: Appeal) => item.punishment_id === this.punishmentId)) {
        this.punishmentId = 0;
      }
    } catch (err) {
      this.loadError = err instanceof ApiError ? err.message : '申诉记录加载失败';
    } finally {
      this.loading = false;
    }
  }

  private async submit(): Promise<void> {
    const reason = this.reason.trim();
    if (this.punishmentId <= 0 || reason.length === 0 || this.submitting) {
      if (reason.length === 0) {
        this.toast('请填写申诉理由');
      }
      return;
    }
    this.submitting = true;
    try {
      await Api.createAppeal(this.punishmentId, reason);
      this.toast('申诉已提交，平台将在 7 天内处理');
      this.reason = '';
      this.punishmentId = 0;
      await this.load();
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '申诉提交失败');
    } finally {
      this.submitting = false;
    }
  }

  private statusText(status: string): string {
    if (status === 'pending') {
      return '待处理';
    }
    if (status === 'lifted') {
      return '处罚已解除';
    }
    if (status === 'upheld') {
      return '维持处罚';
    }
    return status;
  }

  private statusColor(status: string): string {
    if (status === 'lifted') {
      return '#16A34A';
    }
    if (status === 'upheld') {
      return AppColors.DANGER;
    }
    return AppColors.ORANGE;
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '我的申诉',
          onBack: () => this.navStack.pop()
        })

        if (this.loading) {
          LoadingView()
        } else {
          List({ space: 12 }) {
            if (this.punishmentId > 0) {
              ListItem() {
                Column({ space: 12 }) {
                  Text('提交处罚申诉')
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .width('100%')
                  Text(`处罚记录 #${this.punishmentId}。每次处罚只能申诉一次，请完整说明情况。`)
                    .fontSize(13)
                    .lineHeight(20)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .width('100%')
                  TextArea({ placeholder: '请输入申诉理由', text: $$this.reason })
                    .width('100%')
                    .height(120)
                    .fontSize(14)
                    .backgroundColor(AppColors.PAGE_BG)
                    .borderRadius(10)
                  Button(this.submitting ? '提交中…' : '提交申诉')
                    .width('100%')
                    .height(44)
                    .backgroundColor(this.reason.trim().length > 0 ? AppColors.PRIMARY : '#9AB6EA')
                    .enabled(this.reason.trim().length > 0 && !this.submitting)
                    .onClick(() => this.submit())
                }
                .width('100%')
                .padding(16)
                .backgroundColor(AppColors.CARD_BG)
                .borderRadius(14)
              }
            }

            if (this.loadError.length > 0 && this.items.length === 0) {
              ListItem() {
                EmptyState({
                  title: '加载失败',
                  desc: this.loadError,
                  actionText: '重试',
                  onAction: () => this.load()
                })
              }
            } else if (this.items.length === 0 && this.punishmentId === 0) {
              ListItem() {
                EmptyState({ title: '暂无申诉记录', desc: '收到处罚通知后，可从通知详情发起申诉。' })
              }
            }

            ForEach(this.items, (item: Appeal) => {
              ListItem() {
                Column({ space: 9 }) {
                  Row() {
                    Text(item.kind === 'ban' ? '账号封禁申诉' : '禁言申诉')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    Blank()
                    Text(this.statusText(item.status))
                      .fontSize(12)
                      .fontColor(this.statusColor(item.status))
                  }
                  .width('100%')
                  Text(item.reason)
                    .fontSize(14)
                    .lineHeight(21)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .width('100%')
                  if (item.result && item.result.length > 0) {
                    Text(`处理说明：${item.result}`)
                      .fontSize(13)
                      .fontColor(AppColors.TEXT_SECONDARY)
                      .width('100%')
                  }
                  Text(TimeUtil.format(item.created_at))
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .width('100%')
                }
                .width('100%')
                .padding(16)
                .backgroundColor(AppColors.CARD_BG)
                .borderRadius(14)
              }
            }, (item: Appeal) => `${item.id}:${item.status}:${item.result ?? ''}`)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 20 })
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
