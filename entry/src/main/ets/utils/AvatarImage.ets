import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

const AVATAR_EDGE = 512;

/** 将系统相册编辑后的图片居中裁成正方形，并统一编码为 512px JPEG。 */
export async function createSquareAvatar(sourceUri: string, outputPath: string): Promise<void> {
  const inputFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
  const imageSource = image.createImageSource(inputFile.fd);
  try {
    const info = await imageSource.getImageInfo();
    const side = Math.min(info.size.width, info.size.height);
    const region: image.Region = {
      x: Math.floor((info.size.width - side) / 2),
      y: Math.floor((info.size.height - side) / 2),
      size: { width: side, height: side },
    };
    const pixelMap = await imageSource.createPixelMap({
      desiredRegion: region,
      desiredSize: { width: AVATAR_EDGE, height: AVATAR_EDGE },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
    });
    try {
      const packer = image.createImagePacker();
      try {
        const buffer = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 90 });
        const outputFile = fileIo.openSync(
          outputPath,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
        );
        try {
          fileIo.writeSync(outputFile.fd, buffer);
        } finally {
          fileIo.closeSync(outputFile);
        }
      } finally {
        await packer.release();
      }
    } finally {
      await pixelMap.release();
    }
  } finally {
    await imageSource.release();
    fileIo.closeSync(inputFile);
  }
}
