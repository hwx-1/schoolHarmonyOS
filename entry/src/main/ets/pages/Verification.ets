import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { Api } from '../service/Api';
import { ApiError, uploadFile } from '../service/Http';
import { MyVerification, SubmitVerificationBody } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { LoadingView } from '../components/common/LoadingView';
import { FormField } from '../components/common/FormField';
import { NavBar } from '../components/common/NavBar';

@Component
export struct VerificationPage {
  @Consume('navStack') navStack: NavPathStack;
  @State loading: boolean = true;
  @State current: MyVerification | null = null;
  @State realName: string = '';
  @State studentNo: string = '';
  @State materialUrl: string = '';
  @State uploading: boolean = false;
  @State submitting: boolean = false;

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
      const resp = await Api.myVerification();
      this.current = resp.verification;
      if (resp.verification) {
        this.realName = resp.verification.real_name;
        this.studentNo = resp.verification.student_no;
      }
    } catch {
    }
    this.loading = false;
  }

  private statusText(status: string): string {
    switch (status) {
      case 'pending':
        return '审核中';
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已驳回';
      default:
        return status;
    }
  }

  private statusColor(status: string): string {
    switch (status) {
      case 'pending':
        return AppColors.ORANGE;
      case 'approved':
        return '#0A8A4D';
      case 'rejected':
        return AppColors.DANGER;
      default:
        return AppColors.TEXT_SECONDARY;
    }
  }

  private async pickMaterial(): Promise<void> {
    if (this.uploading) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return;
    }
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const fileName = `verify_${Date.now()}.jpg`;
      const cachePath = `${context.cacheDir}/${fileName}`;
      const source = fileIo.openSync(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
      const target = fileIo.openSync(cachePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.copyFileSync(source.fd, target.fd);
      fileIo.closeSync(source);
      fileIo.closeSync(target);

      this.uploading = true;
      const resp = await uploadFile(cachePath, fileName, 'image/jpeg');
      this.materialUrl = resp.url;
      this.toast('材料上传成功');
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '材料上传失败');
    } finally {
      this.uploading = false;
    }
  }

  private canSubmit(): boolean {
    return this.realName.trim().length > 0
      && this.studentNo.trim().length > 0
      && this.materialUrl.length > 0
      && !this.submitting
      && !this.uploading;
  }

  private async submit(): Promise<void> {
    if (!this.canSubmit()) {
      return;
    }
    this.submitting = true;
    try {
      const body: SubmitVerificationBody = {
        material_url: this.materialUrl,
        real_name: this.realName.trim(),
        student_no: this.studentNo.trim(),
      };
      const resp = await Api.submitVerification(body);
      this.current = resp.verification;
      this.toast('认证材料已提交，等待管理员审核');
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '提交失败，请稍后重试');
    } finally {
      this.submitting = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '学生认证',
          onBack: () => {
            this.navStack.pop();
          }
        })

        if (this.loading) {
          LoadingView()
        } else {
          Scroll() {
            Column({ space: 14 }) {
              if (this.current) {
                Row({ space: 8 }) {
                  Text('当前状态')
                    .fontSize(14)
                    .fontColor(AppColors.TEXT_SECONDARY)
                  Text(this.statusText(this.current.status))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.statusColor(this.current.status))
                }
                .width('100%')
                .padding(14)
                .backgroundColor(AppColors.CARD_BG)
                .borderRadius(12)

                if (this.current.status === 'rejected' && this.current.reject_reason) {
                  Text(`驳回原因：${this.current.reject_reason}`)
                    .fontSize(12)
                    .fontColor(AppColors.DANGER)
                    .width('100%')
                }
              }

              if (!this.current || this.current.status === 'rejected') {
                FormField({ label: '真实姓名', placeholder: '与学籍信息一致', value: this.$realName })
                FormField({ label: '学号', placeholder: '请输入学号', value: this.$studentNo })

                Column({ space: 6 }) {
                  Text('认证材料（学生证 / 校园卡照片）')
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .width('100%')
                  Row({ space: 10 }) {
                    Text(this.materialUrl.length > 0 ? '已上传 ✓' : (this.uploading ? '上传中…' : '选择图片'))
                      .fontSize(14)
                      .fontColor(this.materialUrl.length > 0 ? '#0A8A4D' : AppColors.PRIMARY)
                      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                      .backgroundColor(AppColors.CARD_BG)
                      .borderRadius(10)
                      .onClick(() => {
                        this.pickMaterial();
                      })
                  }
                  .width('100%')
                }
                .width('100%')

                Button(this.submitting ? '提交中…' : '提交认证')
                  .width('100%')
                  .height(46)
                  .fontSize(15)
                  .backgroundColor(this.canSubmit() ? AppColors.PRIMARY : '#9AB6EA')
                  .enabled(this.canSubmit())
                  .onClick(() => {
                    this.submit();
                  })
              } else {
                Text('认证信息已在流程中，如需修改请联系管理员。')
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .width('100%')
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .align(Alignment.Top)
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
