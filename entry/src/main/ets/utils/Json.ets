/**
 * JSON 解析工具。
 * ArkTS 禁止 any，服务端 JSON 反序列化统一收敛到这里做一次类型收敛，
 * 调用方拿到的都是强类型对象。
 */
export class Json {
  static parse<T>(text: string): T {
    return JSON.parse(text) as T;
  }

  static tryParse<T>(text: string, fallback: T): T {
    try {
      return JSON.parse(text) as T;
    } catch {
      return fallback;
    }
  }
}
