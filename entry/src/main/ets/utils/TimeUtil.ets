/** 相对时间格式化，与移动端 formatTime 行为一致。 */
export class TimeUtil {
  static format(iso: string): string {
    const time = new Date(iso).getTime();
    if (Number.isNaN(time)) {
      return '';
    }
    const diff = Date.now() - time;
    const minute = 60000;
    if (diff < minute) {
      return '刚刚';
    }
    if (diff < 60 * minute) {
      return `${Math.floor(diff / minute)} 分钟前`;
    }
    if (diff < 24 * 60 * minute) {
      return `${Math.floor(diff / (60 * minute))} 小时前`;
    }
    if (diff < 7 * 24 * 60 * minute) {
      return `${Math.floor(diff / (24 * 60 * minute))} 天前`;
    }
    const date = new Date(time);
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }
}
