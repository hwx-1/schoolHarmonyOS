import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { Api } from '../service/Api';
import { ApiError, uploadFile } from '../service/Http';
import { AppColors, AppConfig } from '../constants/AppConfig';
import { CreatePostBody } from '../model/Types';
import { NavBar } from '../components/common/NavBar';

/** 待上传图片：本地缓存路径 + 可选的远端 URL（上传完成后回填）。 */
interface PendingImage {
  localPath: string;
  remoteUrl: string;
  uploading: boolean;
}

@Component
export struct ComposePage {
  @Consume('navStack') navStack: NavPathStack;
  @State text: string = '';
  @State tagInput: string = '';
  @State tags: string[] = [];
  @State images: PendingImage[] = [];
  @State publishing: boolean = false;

  private canPublish(): boolean {
    return this.text.trim().length > 0
      && !this.publishing
      && !this.images.some((img: PendingImage) => img.uploading);
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch {
      // Toast 失败不影响主流程
    }
  }

  private async pickImages(): Promise<void> {
    const remain = AppConfig.MAX_POST_IMAGES - this.images.length;
    if (remain <= 0) {
      this.toast(`最多上传 ${AppConfig.MAX_POST_IMAGES} 张图片`);
      return;
    }
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: remain,
      });
      const uris = result.photoUris;
      for (const uri of uris) {
        await this.importImage(uri);
      }
    } catch {
      // 用户取消选择，不提示
    }
  }

  /** 把相册图片复制进应用缓存目录后发起上传。 */
  private async importImage(uri: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return;
    }
    const fileName = `post_${Date.now()}_${Math.floor(Math.random() * 100000)}.jpg`;
    const cachePath = `${context.cacheDir}/${fileName}`;
    try {
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const target = fileIo.openSync(cachePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.copyFileSync(source.fd, target.fd);
      fileIo.closeSync(source);
      fileIo.closeSync(target);
    } catch {
      this.toast('图片读取失败，请重试');
      return;
    }

    const pending: PendingImage = { localPath: cachePath, remoteUrl: '', uploading: true };
    this.images = [...this.images, pending];
    const index = this.images.length - 1;
    try {
      const resp = await uploadFile(cachePath, fileName, 'image/jpeg');
      const next: PendingImage = { localPath: cachePath, remoteUrl: resp.url, uploading: false };
      this.images = this.images.map((img: PendingImage, i: number) => i === index ? next : img);
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '图片上传失败');
      this.images = this.images.filter((img: PendingImage, i: number) => i !== index);
    }
  }

  private removeImage(index: number): void {
    this.images = this.images.filter((img: PendingImage, i: number) => i !== index);
  }

  private addTag(): void {
    const tag = this.tagInput.trim().replace(/^#/, '');
    if (tag.length === 0) {
      return;
    }
    if (this.tags.indexOf(tag) >= 0) {
      this.toast('标签已存在');
      return;
    }
    if (this.tags.length >= AppConfig.MAX_POST_TAGS) {
      this.toast(`最多 ${AppConfig.MAX_POST_TAGS} 个标签`);
      return;
    }
    this.tags = [...this.tags, tag];
    this.tagInput = '';
  }

  private removeTag(tag: string): void {
    this.tags = this.tags.filter((item: string) => item !== tag);
  }

  private async publish(): Promise<void> {
    if (!this.canPublish()) {
      return;
    }
    this.publishing = true;
    try {
      const body: CreatePostBody = {
        text: this.text.trim(),
        images: this.images.map((img: PendingImage) => img.remoteUrl),
        tags: this.tags,
      };
      const resp = await Api.createPost(body);
      if (!resp.moderation.pass) {
        this.toast(resp.message || '内容未通过审核，请修改后重试');
      } else {
        this.toast(resp.message || '发布成功');
        this.navStack.pop();
      }
    } catch (err) {
      this.toast(err instanceof ApiError ? err.message : '发布失败，请稍后重试');
    } finally {
      this.publishing = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavBar({
          title: '发布动态',
          showBack: false,
          leftText: '取消',
          onLeft: () => {
            this.navStack.pop();
          },
          rightText: this.publishing ? '发布中…' : '发布',
          rightEnabled: this.canPublish(),
          onRight: () => {
            this.publish();
          }
        })

        Scroll() {
          Column({ space: 14 }) {
            TextArea({ placeholder: '分享校园里的新鲜事…', text: $$this.text })
              .width('100%')
              .height(140)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(12)
              .padding(12)

            // 图片九宫格
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.images, (img: PendingImage, index: number) => {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Stack() {
                    Image(`file://${img.localPath}`)
                      .width(100)
                      .height(100)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(10)
                    if (img.uploading) {
                      Stack() {
                        LoadingProgress()
                          .width(28)
                          .height(28)
                          .color(Color.White)
                      }
                      .width(100)
                      .height(100)
                      .borderRadius(10)
                      .backgroundColor('#66000000')
                    }
                  }
                  Text('✕')
                    .fontSize(12)
                    .fontColor(Color.White)
                    .width(22)
                    .height(22)
                    .textAlign(TextAlign.Center)
                    .backgroundColor('#99000000')
                    .borderRadius(11)
                    .margin(4)
                    .onClick(() => this.removeImage(index))
                }
                .margin({ right: 8, bottom: 8 })
              }, (img: PendingImage) => img.localPath)

              if (this.images.length < AppConfig.MAX_POST_IMAGES) {
                Column({ space: 4 }) {
                  Text('＋')
                    .fontSize(26)
                    .fontColor(AppColors.TEXT_SECONDARY)
                  Text('添加图片')
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .width(100)
                .height(100)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(AppColors.CARD_BG)
                .borderRadius(10)
                .border({ width: 1, color: AppColors.DIVIDER, style: BorderStyle.Dashed })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.pickImages();
                })
              }
            }
            .width('100%')

            // 标签
            Column({ space: 8 }) {
              Row({ space: 10 }) {
                TextInput({ placeholder: `添加话题标签（最多 ${AppConfig.MAX_POST_TAGS} 个）`, text: $$this.tagInput })
                  .layoutWeight(1)
                  .height(40)
                  .backgroundColor(AppColors.CARD_BG)
                  .borderRadius(10)
                  .onSubmit(() => this.addTag())
                Button('添加')
                  .height(40)
                  .fontSize(13)
                  .backgroundColor(AppColors.PRIMARY)
                  .onClick(() => this.addTag())
              }
              if (this.tags.length > 0) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tags, (tag: string) => {
                    Row({ space: 4 }) {
                      Text(`# ${tag}`)
                        .fontSize(12)
                        .fontColor(AppColors.PRIMARY)
                      Text('✕')
                        .fontSize(11)
                        .fontColor(AppColors.TEXT_SECONDARY)
                    }
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor('#1A2E6BE6')
                    .borderRadius(12)
                    .margin({ right: 8, bottom: 4 })
                    .onClick(() => this.removeTag(tag))
                  }, (tag: string) => tag)
                }
                .width('100%')
              }
            }
            .width('100%')

            Text('发布前请确认内容符合社区公约；演示环境内置内容审核，命中违禁词将被拦截。')
              .fontSize(11)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
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
}
