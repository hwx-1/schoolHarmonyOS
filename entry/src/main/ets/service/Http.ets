import { http } from '@kit.NetworkKit';
import { AppConfig } from '../constants/AppConfig';
import { ApiErrorBody } from '../model/Types';
import { Json } from '../utils/Json';
import { mockRequest } from './Mock';

export class ApiError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

/**
 * Cookie 会话罐：服务端基于 Cookie 鉴权，
 * 登录后捕获 Set-Cookie，后续请求统一携带；
 * 非 GET 请求自动附加 X-CSRF-Token（取自 xsnbb_csrf Cookie）。
 */
export class CookieJar {
  private static cookies: Map<string, string> = new Map();

  static absorb(setCookie: string | string[] | undefined): void {
    if (!setCookie) {
      return;
    }
    const lines: string[] = Array.isArray(setCookie) ? setCookie : [setCookie];
    lines.forEach((line: string) => {
      const pair = line.split(';')[0];
      const eq = pair.indexOf('=');
      if (eq > 0) {
        const name = pair.substring(0, eq).trim();
        const value = pair.substring(eq + 1).trim();
        if (value.length === 0 || value === 'deleted') {
          CookieJar.cookies.delete(name);
        } else {
          CookieJar.cookies.set(name, value);
        }
      }
    });
  }

  static header(): string {
    const parts: string[] = [];
    CookieJar.cookies.forEach((value: string, key: string) => {
      parts.push(`${key}=${value}`);
    });
    return parts.join('; ');
  }

  static csrfToken(): string {
    return CookieJar.cookies.get('xsnbb_csrf') ?? '';
  }

  static clear(): void {
    CookieJar.cookies.clear();
  }

  static hasSession(): boolean {
    return CookieJar.cookies.size > 0;
  }
}

interface HttpResult<T> {
  ok: boolean;
  status: number;
  data: T;
}

async function rawRequest(
  method: http.RequestMethod,
  path: string,
  bodyText: string | undefined,
  extraHeaders: Record<string, string>,
): Promise<HttpResult<string>> {
  const client = http.createHttp();
  try {
    const header: Record<string, string> = {
      'Accept': 'application/json',
    };
    const cookie = CookieJar.header();
    if (cookie.length > 0) {
      header['Cookie'] = cookie;
    }
    if (bodyText !== undefined) {
      header['Content-Type'] = 'application/json';
    }
    if (method !== http.RequestMethod.GET) {
      const csrf = CookieJar.csrfToken();
      if (csrf.length > 0) {
        header['X-CSRF-Token'] = csrf;
      }
    }
    Object.keys(extraHeaders).forEach((key: string) => {
      header[key] = extraHeaders[key];
    });

    const response = await client.request(`${AppConfig.API_BASE_URL}${path}`, {
      method: method,
      header: header,
      extraData: bodyText,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false,
      connectTimeout: AppConfig.REQUEST_TIMEOUT_MS,
      readTimeout: AppConfig.REQUEST_TIMEOUT_MS,
    });

    const headerMap = response.header as Record<string, string | string[]>;
    const setCookie: string | string[] | undefined =
      headerMap['set-cookie'] ?? headerMap['Set-Cookie'];
    CookieJar.absorb(setCookie);

    const text: string =
      typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
    return { ok: response.responseCode >= 200 && response.responseCode < 300, status: response.responseCode, data: text };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'network error';
    throw new ApiError(0, 'NETWORK_ERROR', `暂时无法连接服务器，请检查网络后重试（${message}）`);
  } finally {
    client.destroy();
  }
}

export async function request<T>(
  method: http.RequestMethod,
  path: string,
  body?: object,
): Promise<T> {
  if (AppConfig.USE_LOCAL_MOCK) {
    return mockRequest<T>(method, path, body);
  }
  const bodyText = body === undefined ? undefined : JSON.stringify(body);
  const result = await rawRequest(method, path, bodyText, {});
  if (result.status === 204 || result.data.length === 0) {
    return undefined as T;
  }
  if (!result.ok) {
    const payload = Json.tryParse<ApiErrorBody>(result.data, {});
    throw new ApiError(
      result.status,
      payload.error?.code ?? 'UNKNOWN',
      payload.error?.message ?? '请求失败，请稍后重试',
    );
  }
  return Json.parse<T>(result.data);
}

/** 图片上传：multipart/form-data。 */
export async function uploadFile(
  filePath: string,
  fileName: string,
  contentType: string,
): Promise<TUploadResult> {
  if (AppConfig.USE_LOCAL_MOCK) {
    // Mock 模式直接保留缓存文件 URI，头像和帖子图片均可在当前会话中正常预览。
    const result: TUploadResult = { url: `file://${filePath}`, dev_mode: true };
    return result;
  }
  const client = http.createHttp();
  try {
    const header: Record<string, string> = {};
    const cookie = CookieJar.header();
    if (cookie.length > 0) {
      header['Cookie'] = cookie;
    }
    const csrf = CookieJar.csrfToken();
    if (csrf.length > 0) {
      header['X-CSRF-Token'] = csrf;
    }
    const formData: http.MultiFormData = {
      name: 'file',
      contentType: contentType,
      remoteFileName: fileName,
      filePath: filePath,
    };
    const response = await client.request(`${AppConfig.API_BASE_URL}/api/v1/uploads`, {
      method: http.RequestMethod.POST,
      header: header,
      multiFormDataList: [formData],
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: AppConfig.REQUEST_TIMEOUT_MS,
      readTimeout: AppConfig.REQUEST_TIMEOUT_MS * 4,
    });
    const text: string =
      typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
    if (response.responseCode < 200 || response.responseCode >= 300) {
      const payload = Json.tryParse<ApiErrorBody>(text, {});
      throw new ApiError(
        response.responseCode,
        payload.error?.code ?? 'UPLOAD_FAILED',
        payload.error?.message ?? '图片上传失败',
      );
    }
    return Json.parse<TUploadResult>(text);
  } catch (err) {
    if (err instanceof ApiError) {
      throw err;
    }
    const message = err instanceof Error ? err.message : 'upload error';
    throw new ApiError(0, 'NETWORK_ERROR', `图片上传失败，请检查网络后重试（${message}）`);
  } finally {
    client.destroy();
  }
}

export interface TUploadResult {
  url: string;
  dev_mode: boolean;
}

export function absoluteMediaUrl(path: string | undefined): string {
  if (!path || path.length === 0) {
    return '';
  }
  if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('file://')) {
    return path;
  }
  return `${AppConfig.API_BASE_URL}${path.startsWith('/') ? path : `/${path}`}`;
}
