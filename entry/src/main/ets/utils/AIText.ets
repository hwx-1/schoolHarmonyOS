/**
 * AI 回答文本处理：去除大模型输出中的 Markdown 记号，
 * 规则与安卓端 / web 端的 formatAIAnswer 保持一致，方便用普通 Text 直接展示。
 */
export class AIText {
  private static readonly HEADING: RegExp = /^#{1,6}\s*/gm;
  private static readonly BOLD_STAR: RegExp = /\*\*([^*]+)\*\*/g;
  private static readonly BOLD_UNDERSCORE: RegExp = /__([^_]+)__/g;
  // 首组捕获前一个字符（非字母数字或 *）以代替 lookbehind，避免依赖引擎对 (?<!) 的支持。
  private static readonly ITALIC: RegExp = /(^|[^\w*])\*([^*\n]+)\*(?![\w*])/g;
  private static readonly FENCED_CODE: RegExp = /```[\s\S]*?```/g;
  private static readonly INLINE_CODE: RegExp = /`([^`]*)`/g;
  private static readonly UNORDERED_LIST: RegExp = /^\s*[-*+]\s+/gm;
  private static readonly ORDERED_LIST: RegExp = /^\s{0,3}(\d+)[.、]\s+/gm;
  private static readonly QUOTE: RegExp = /^\s*>\s?/gm;
  private static readonly LINK: RegExp = /\[([^\]]*)\]\([^)]*\)/g;
  private static readonly BLANK_LINES: RegExp = /\n{3,}/g;

  static formatAnswer(text: string): string {
    return text
      .replace(/\r\n/g, '\n')
      .replace(AIText.HEADING, '')
      .replace(AIText.BOLD_STAR, '$1')
      .replace(AIText.BOLD_UNDERSCORE, '$1')
      .replace(AIText.ITALIC, '$1$2')
      .replace(AIText.FENCED_CODE, (block: string) => block.replace(/`/g, ''))
      .replace(AIText.INLINE_CODE, '$1')
      .replace(AIText.UNORDERED_LIST, '· ')
      .replace(AIText.ORDERED_LIST, '$1. ')
      .replace(AIText.QUOTE, '')
      .replace(AIText.LINK, '$1')
      .replace(AIText.BLANK_LINES, '\n\n')
      .trim();
  }
}
