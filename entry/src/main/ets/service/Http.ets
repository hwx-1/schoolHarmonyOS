import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
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
    const header = buildHeaders(method, bodyText !== undefined, 'application/json');
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

function buildHeaders(method: http.RequestMethod, hasBody: boolean, accept: string): Record<string, string> {
  const header: Record<string, string> = {
    'Accept': accept,
  };
  const cookie = CookieJar.header();
  if (cookie.length > 0) {
    header['Cookie'] = cookie;
  }
  if (hasBody) {
    header['Content-Type'] = 'application/json';
  }
  if (method !== http.RequestMethod.GET) {
    const csrf = CookieJar.csrfToken();
    if (csrf.length > 0) {
      header['X-CSRF-Token'] = csrf;
    }
  }
  return header;
}

/**
 * SSE 流式请求：逐行读取 `data:` 事件并回调 payload 文本（已去掉 `data:` 前缀）。
 * 忽略 event/id/retry 行与空行；服务端响应非 2xx 时在流结束后抛出 ApiError。
 * 回调在主线程（ArkTS 单线程事件循环）触发，可直接更新 @State。
 */
export function streamRequest(
  method: http.RequestMethod,
  path: string,
  body: object | undefined,
  onData: (payload: string) => void,
): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const client = http.createHttp();
    const decoder = util.TextDecoder.create('utf-8');
    let status = 0;
    let requestDone = false;
    let dataEnded = false;
    let settled = false;
    let pending = '';
    let rawText = '';

    const finish = (err?: ApiError): void => {
      if (settled) {
        return;
      }
      settled = true;
      client.off('headersReceive');
      client.off('dataReceive');
      client.off('dataEnd');
      client.destroy();
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    };

    const emitLine = (line: string): void => {
      const trimmed = line.trim();
      if (trimmed.startsWith('data:')) {
        onData(trimmed.substring(5).trim());
      }
    };

    const tryComplete = (): void => {
      if (!requestDone || !dataEnded) {
        return;
      }
      if (status < 200 || status >= 300) {
        const payload = Json.tryParse<ApiErrorBody>(rawText, {});
        finish(new ApiError(
          status,
          payload.error?.code ?? 'UNKNOWN',
          payload.error?.message ?? '请求失败，请稍后重试',
        ));
        return;
      }
      if (pending.length > 0) {
        emitLine(pending);
        pending = '';
      }
      finish();
    };

    client.on('headersReceive', (headers: Object) => {
      const headerMap = headers as Record<string, string | string[]>;
      CookieJar.absorb(headerMap['set-cookie'] ?? headerMap['Set-Cookie']);
    });
    client.on('dataReceive', (chunk: ArrayBuffer) => {
      const text = decoder.decodeToString(new Uint8Array(chunk), { stream: true });
      // 错误响应体一般很短，截断保留即可用于解析 error.message
      if (rawText.length < 4096) {
        rawText += text;
      }
      pending += text;
      let newline = pending.indexOf('\n');
      while (newline >= 0) {
        emitLine(pending.substring(0, newline));
        pending = pending.substring(newline + 1);
        newline = pending.indexOf('\n');
      }
    });
    client.on('dataEnd', () => {
      dataEnded = true;
      tryComplete();
    });

    const bodyText = body === undefined ? undefined : JSON.stringify(body);
    client.requestInStream(`${AppConfig.API_BASE_URL}${path}`, {
      method: method,
      header: buildHeaders(method, bodyText !== undefined, 'text/event-stream'),
      extraData: bodyText,
      usingCache: false,
      connectTimeout: AppConfig.REQUEST_TIMEOUT_MS,
      readTimeout: AppConfig.STREAM_TIMEOUT_MS,
    }).then((code: number) => {
      status = code;
      requestDone = true;
      tryComplete();
      if (code < 200 || code >= 300) {
        // 错误响应可能没有响应体、不触发 dataEnd：短暂等待后强制结束，避免挂起
        setTimeout(() => {
          dataEnded = true;
          tryComplete();
        }, 300);
      }
    }).catch((err: Error) => {
      const message = err instanceof Error ? err.message : 'network error';
      finish(new ApiError(0, 'NETWORK_ERROR', `暂时无法连接服务器，请检查网络后重试（${message}）`));
    });
  });
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
