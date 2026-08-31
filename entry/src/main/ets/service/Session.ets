import { Api } from './Api';
import { ApiError, CookieJar } from './Http';
import { Account } from '../model/Types';

const KEY_ACCOUNT = 'xsnbb_account';
const KEY_LOGGED_IN = 'xsnbb_logged_in';

/**
 * 全局会话状态。
 * 登录成功后把 Account 写入 AppStorage，页面用 @StorageProp 订阅；
 * Cookie 由 CookieJar 在进程内持有（内存会话，与移动端内存种子数据语义一致）。
 */
export class Session {
  static currentAccount(): Account | null {
    const value = AppStorage.get<Account | null>(KEY_ACCOUNT);
    return value ?? null;
  }

  static isLoggedIn(): boolean {
    return AppStorage.get<boolean>(KEY_LOGGED_IN) ?? false;
  }

  static applyAccount(account: Account): void {
    AppStorage.setOrCreate<Account | null>(KEY_ACCOUNT, account);
    AppStorage.setOrCreate<boolean>(KEY_LOGGED_IN, true);
  }

  /** 冷启动时尝试用已有 Cookie 恢复登录态。 */
  static async restore(): Promise<boolean> {
    if (!CookieJar.hasSession()) {
      Session.clear();
      return false;
    }
    try {
      const resp = await Api.me();
      Session.applyAccount(resp.account);
      return true;
    } catch (err) {
      if (err instanceof ApiError && (err.status === 401 || err.status === 403)) {
        Session.clear();
        return false;
      }
      // 网络异常时保留本地态，由页面自行提示重试
      return Session.isLoggedIn();
    }
  }

  static clear(): void {
    CookieJar.clear();
    AppStorage.setOrCreate<Account | null>(KEY_ACCOUNT, null);
    AppStorage.setOrCreate<boolean>(KEY_LOGGED_IN, false);
  }

  static async logout(): Promise<void> {
    try {
      await Api.logout();
    } catch {
      // 忽略登出接口异常，本地态必须清理
    }
    Session.clear();
  }
}
