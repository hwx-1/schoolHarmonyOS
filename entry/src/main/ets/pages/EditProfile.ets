import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Api } from '../service/Api';
import { ApiError, uploadFile } from '../service/Http';
import { Session } from '../service/Session';
import { UpdateProfileBody } from '../model/Types';
import { AppColors } from '../constants/AppConfig';
import { FormField } from '../components/common/FormField';
import { AvatarView } from '../components/common/AvatarView';
import { NavBar } from '../components/common/NavBar';
import { createSquareAvatar } from '../utils/AvatarImage';

@Component
export struct EditProfilePage {
  @Consume('navStack') navStack: NavPathStack;
  @State nickname: string = '';
  @State gender: string = '';
  @State realName: string = '';
  @State studentNo: string = '';
  @State className: string = '';
  @State avatar: string = '';
  @State avatarPreview: string = '';
  @State avatarUploading: boolean = false;
  @State saving: boolean = false;

  aboutToAppear(): void {
    const account = Session.currentAccount();
    if (account) {
      this.nickname = account.nickname;
      this.gender = account.gender;
      this.realName = account.real_name ?? '';
      this.studentNo = account.student_no ?? '';
      this.className = account.class_name ?? '';
      this.avatar = account.avatar;
      this.avatarPreview = account.avatar;
    }
  }

  private canSave(): boolean {
    return this.nickname.trim().length > 0 && !this.saving && !this.avatarUploading;
  }

  private async pickAvatar(): Promise<void> {
    if (this.avatarUploading) {
      return;
    }
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
        isEditSupported: true,
        isPhotoTakingSupported: true,
        isPreviewForSingleSelectionSupported: true,
      });
      if (result.photoUris.length === 0) {
        return;
      }
      await this.cropAndUploadAvatar(result.photoUris[0]);
    } catch {
      // 用户取消选择或裁剪时不提示
    }
  }

  private async cropAndUploadAvatar(sourceUri: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return;
    }
    this.avatarUploading = true;
    const fileName = `avatar_${Date.now()}.jpg`;
    const cachePath = `${context.cacheDir}/${fileName}`;
    try {
      await createSquareAvatar(sourceUri, cachePath);
      this.avatarPreview = `file://${cachePath}`;
      const response = await uploadFile(cachePath, fileName, 'image/jpeg');
      this.avatar = response.url;
      this.toast('头像已裁剪，保存资料后生效');
    } catch (err) {
      this.avatarPreview = this.avatar;
      this.toast(err instanceof ApiError ? err.message : '头像处理失败，请重新选择');
    } finally {
      this.avatarUploading = false;
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    if (this.avatarUploading) {
      this.toast('头像正在处理中，请稍候');
      return;
    }
    if (this.nickname.trim().length === 0) {
      this.toast('昵称不能为空');
      return;
    }
    this.saving = true;
    try {
      const body: UpdateProfileBody = {
        nickname: this.nickname.trim(),
        avatar: this.avatar,
        gender: this.gender,
        real_name: this.realName.trim(),
        student_no: this.studentNo.trim(),
        class_name: this.className.trim(),
      };
      const resp = await Api.updateProfile(body);
      Session.applyAccount(resp.account);
      this.toast('资料已保存');
      this.navStack.pop();
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '保存失败，请稍后重试');
    } finally {
      this.saving = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '编辑资料',
          showBack: false,
          leftText: '取消',
          onLeft: () => {
            this.navStack.pop();
          },
          rightText: this.saving ? '保存中…' : '保存',
          rightEnabled: this.canSave(),
          onRight: () => {
            this.save();
          }
        })

        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 10 }) {
              Stack({ alignContent: Alignment.BottomEnd }) {
                AvatarView({
                  avatar: this.avatarPreview,
                  nickname: this.nickname,
                  diameter: 88
                })
                Stack() {
                  Text('✎')
                    .fontSize(15)
                    .fontColor(Color.White)
                }
                .width(28)
                .height(28)
                .borderRadius(14)
                .backgroundColor(AppColors.PRIMARY)
                .border({ width: 2, color: AppColors.CARD_BG })
              }
              .width(96)
              .height(96)

              if (this.avatarUploading) {
                Row({ space: 6 }) {
                  LoadingProgress()
                    .width(16)
                    .height(16)
                    .color(AppColors.PRIMARY)
                  Text('正在裁剪并上传…')
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
              } else {
                Text('更换头像')
                  .fontSize(14)
                  .fontColor(AppColors.PRIMARY)
              }
              Text('支持拍照或从相册选择，可在系统编辑页调整裁剪区域')
                .fontSize(11)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
            .width('100%')
            .padding({ top: 18, bottom: 18 })
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(14)
            .onClick(() => this.pickAvatar())

            FormField({ label: '昵称', placeholder: '请输入昵称', value: this.$nickname })
            this.GenderPicker()
            FormField({ label: '真实姓名', placeholder: '选填', value: this.$realName })
            FormField({ label: '学号', placeholder: '选填', value: this.$studentNo })
            FormField({ label: '班级', placeholder: '选填', value: this.$className })

            Text('学号与班级将用于学生认证核验，请如实填写。')
              .fontSize(11)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
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
  private GenderPicker() {
    Column({ space: 6 }) {
      Text('性别')
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
      Row({ space: 10 }) {
        ForEach(['男', '女', '保密'], (option: string) => {
          Text(option)
            .fontSize(14)
            .fontColor(this.gender === option ? Color.White : AppColors.TEXT_PRIMARY)
            .padding({ left: 18, right: 18, top: 8, bottom: 8 })
            .backgroundColor(this.gender === option ? AppColors.PRIMARY : AppColors.CARD_BG)
            .borderRadius(18)
            .onClick(() => {
              this.gender = option;
            })
        }, (option: string) => option)
      }
      .width('100%')
    }
    .width('100%')
  }
}
