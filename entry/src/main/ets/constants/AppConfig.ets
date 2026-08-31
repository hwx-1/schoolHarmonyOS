/**
 * 全局常量与接口配置。
 * 真机联调时将 API_BASE_URL 改为电脑局域网地址或线上 HTTPS 地址；
 * HarmonyOS 模拟器访问宿主机时同样使用局域网 IP。
 */
export class AppConfig {
  static readonly APP_VERSION: string = '1.0.0';
  static readonly BUILD_VERSION: string = '1';
  // 当前真机 / 模拟器联调电脑地址；服务端源码位于 /Users/zhihu/school/server。
  static readonly API_BASE_URL: string = 'http://10.19.236.131:8080';
  static readonly REQUEST_TIMEOUT_MS: number = 15000;
  static readonly MAX_POST_IMAGES: number = 9;
  static readonly MAX_POST_TAGS: number = 3;

  /**
   * 本地 Mock 模式：true 时所有接口走 service/Mock.ets 的内存数据，
   * 无需后端即可验证 App 内样式与交互；联调真实后端时改为 false。
   */
  static readonly USE_LOCAL_MOCK: boolean = false;
}

/** 与设计基线一致的十六进制色值，供代码内直接使用。 */
export class AppColors {
  static readonly PRIMARY: string = '#2E6BE6';
  static readonly DANGER: string = '#E5484D';
  static readonly ORANGE: string = '#FF6B00';
  static readonly PAGE_BG: string = '#F7F8FA';
  static readonly CARD_BG: string = '#FFFFFF';
  static readonly TEXT_PRIMARY: string = '#1A1A1A';
  static readonly TEXT_SECONDARY: string = '#6B7280';
  static readonly DIVIDER: string = '#E5E7EB';
}
