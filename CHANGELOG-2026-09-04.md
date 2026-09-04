# 变更说明：AI 问答对齐安卓端（SSE 流式、思考过程、对话记录）

日期：2026-09-04
范围：HarmonyOS 客户端（entry 模块）
参照：安卓端 `CHANGELOG-2026-09-03.md`「一、AI 问答重构」（提交 `3290ae8` / `815b5ad`）
构建验证：hvigor `assembleHap` 通过（BUILD SUCCESSFUL）；已通过"注入类型错误 → 编译报错 → 恢复"确认 CompileArkTS 对新增文件生效

---

## 一、功能对齐清单

| 能力 | 安卓端 | 鸿蒙端（本次） |
| --- | --- | --- |
| 进入即新对话 | `Route.AI` → 自动建会话 → `nav.replace(AIChat)` | 路由 `AI` → `AIChatPage({ conversationId: 0 })` → 自动建会话 → `replacePath('AIChat')` |
| 对话记录 | `HistoryDialog` 弹层 | `bindSheet` 半模态弹层（可切换 / 删除会话） |
| 新对话 | 顶栏「新对话」 | 顶栏「新对话」（生成中禁用） |
| SSE 流式回答 | `Http.stream` + `Api.askAIStream` | `streamRequest` + `Api.askAIStream` |
| 思考过程 | 「思考过程」默认收起，可展开 | 同左（`AIAnswerBubble` 内 `@State expanded`） |
| 乐观展示用户消息 | 负数临时 id，`done` 后替换 | 同左 |
| 回答去 Markdown | `formatAIAnswer` 13 条正则 | `AIText.formatAnswer` 同规则 |
| AI 气泡样式 | 白卡 + 边框 + 圆角 16 | 同左 |
| 「深度思考 / 联网搜索」胶囊 | 仅本地开关，不参与请求 | 同左（保持一致，未接后端参数） |
| 知识库反馈（有帮助 / 联网重答） | 字段已解析但 UI 未消费 | **保留**鸿蒙端原有实现 |
| 模型选择胶囊 | 无（固定传空模型） | 随旧列表页一并移除 |

## 二、网络层：新增 SSE 流式请求

### `service/Http.ets`

- 新增 `streamRequest(method, path, body, onData)`：
  - 基于 `http.createHttp().requestInStream()`，订阅 `headersReceive`（吸收 Set-Cookie）、`dataReceive`（增量）、`dataEnd`（结束）三个事件；
  - 用 `util.TextDecoder.decodeToString(..., { stream: true })` 流式解码 UTF-8，多字节字符跨 chunk 不会乱码；
  - 按 `\n` 切行，半行留在 `pending` 缓冲等下一个 chunk；只识别 `data:` 前缀行（与安卓一致，忽略 `event:` / `id:` / `retry:`），去掉前缀后回调；
  - 非 2xx：正文累积到 `rawText`（上限 4 KB）用于解析 `{error:{code,message}}`，流结束后抛与 `request()` 相同的 `ApiError`；错误响应可能没有响应体、不触发 `dataEnd`，promise 决议后 300ms 强制结束，避免挂起；
  - 网络异常统一转为 `ApiError(0, 'NETWORK_ERROR', ...)`；任何路径都会 `off` 事件并 `destroy()` 客户端。
- 抽出 `buildHeaders(method, hasBody, accept)`：Cookie / Content-Type / X-CSRF-Token 拼装逻辑与 `rawRequest` 共用，流式请求 `Accept: text/event-stream`。

### `constants/AppConfig.ets`

- 新增 `STREAM_TIMEOUT_MS = 120000`：流式读超时，与安卓 `streamClient` 一致（普通请求仍为 15s）。

### `service/Api.ets`

- 新增 `askAIStream(id, text, model, onEvent)`：请求 `POST /api/v1/ai/conversations/{id}/messages/stream`；
  - 空载荷与 `[DONE]` 哨兵直接丢弃；JSON 解析失败或缺 `type` 的帧静默跳过；
  - `USE_LOCAL_MOCK = true` 时退化为 `askAI()` 非流式接口，并合成 `text` + `done` 两个事件，Mock 联调链路不受影响。
- 原 `askAI`（非流式）保留，供 Mock 退化路径使用。

### `model/Types.ets`

- `AIMessage` 新增 `reasoning?: string`（思考过程）。
- 新增 `AIStreamEvent { type; delta?; message?; user_message?; answer?; remaining? }`，`type` 取值 `thinking / text / done / error`。

## 三、文本处理：`utils/AIText.ets`

`AIText.formatAnswer(text)` 逐条对齐安卓 / web 端 `formatAIAnswer`：

| 顺序 | 规则 | 处理 |
| --- | --- | --- |
| 1 | `\r\n` | 归一为 `\n` |
| 2 | 标题 `#`~`######` | 去掉记号 |
| 3 | 粗体 `**x**` / `__x__` | 保留内容 |
| 4 | 斜体 `*x*` | 保留内容（见下方说明） |
| 5 | 围栏代码块 ``` | 只去反引号，保留代码内容 |
| 6 | 行内代码 `` `x` `` | 保留内容 |
| 7 | 无序列表 `- * +` | 替换为 `· ` |
| 8 | 有序列表 `1.` / `1、` | 归一为 `1. ` |
| 9 | 引用 `>` | 去掉记号 |
| 10 | 链接 `[文字](url)` | 只留文字 |
| 11 | 3 个以上连续空行 | 折叠为 2 个 |

- 斜体规则安卓用 lookbehind `(?<![\w*])`，鸿蒙改写为等价的 `(^|[^\w*])\*([^*\n]+)\*(?![\w*])` → `$1$2`，不依赖引擎对 lookbehind 的支持；`2*3*4` 这类乘法表达式不会被误删。
- 正则全部缓存为 `static readonly`，流式增量每帧重跑时不重复构造。
- 已用 Node 跑样例验证输出与安卓规则一致。

## 四、页面重写：`pages/AIChat.ets`

### 状态

`messages` / `remaining` / `draft` / `asking` / `title` / `conversations` / `showHistory` / `deepThink` / `webSearch` / `streamReasoning` / `streamText` / `feedbackPendingId`（均 `@State`），`pendingUserTempId` / `scrollScheduled` 为普通私有字段。

### 生命周期

- `aboutToAppear`：`conversationId === 0` → `createAndReplace(popOnFail = true)`，建会话成功后 `replacePath({ name: 'AIChat', param })`，失败 toast 并 `pop()`；否则 `loadCurrent()`（`GET /ai/conversations` 一次性拉全部会话，从中 `find` 当前会话的消息与标题，与安卓一致）。
- 建会话期间列表区显示 `LoadingView`。

### 提问链路 `ask()`

1. 校验：空文本 / 生成中 / 尚无会话 id 直接返回。
2. `asking = true`，清空草稿，以 `-Date.now()` 作临时 id 立即追加用户消息。
3. `Api.askAIStream(...)`，事件分发 `handleStreamEvent`：
   - `thinking` → 累积 `streamReasoning`；`text` → 累积 `streamText`；两者都触发滚动到底；
   - `done` → 过滤掉临时用户消息，用 `event.user_message` / `event.answer` 替换（缺失时用本地累积内容兜底，`reasoning` 为空则不写），更新 `remaining`，重置流式状态；
   - `error` → toast `event.message`（默认「回答中断，本次不扣额度」），重置流式状态。
4. 流正常结束但从未收到 `done`（`asking` 仍为 true）→ 本地合成一次 `done`，保留已生成内容。
5. 请求抛出 `ApiError` → toast 并重置。

### 滚动

`scrollToBottom()` 以 `scrollScheduled` 标记合并 60ms 内的重复请求，流式逐字增量不会堆积大量 `setTimeout`。

### 顶栏

`NavBar` 新增 `rightSecondaryText / rightSecondaryColor / onRightSecondary`（次级右侧文字操作，位于 `rightText` 左侧），有次级操作时标题两侧留白由 72 加宽为 108。AI 对话页：`rightSecondaryText: '对话记录'`、`rightText: '新对话'`（13 号）。

### 对话记录弹层 `HistorySheet`

- `bindSheet($$this.showHistory, ...)`，`SheetSize.MEDIUM`、拖拽条、内置标题「对话记录」与关闭按钮、背景 `PAGE_BG`。
- 打开时重新拉取会话列表，按 `created_at` 倒序。
- 条目：标题（空则「未命名会话」）、`N 条消息`、时间、「删除」；当前会话高亮 `#142E6BE6`；点击 `replacePath` 切换（点当前会话只关弹层）。
- 删除走 `showDialog` 二次确认；删的是当前会话时自动新建一个会话接着聊。
- ForEach 键值：`${id}:${title}:${messages.length}:${是否当前}`。

### 消息列表

- 用户消息：右侧 `#EFF3FA` 圆角 18 气泡，`maxWidth 78%`（沿用）。
- AI 消息：`AIAnswerBubble`（见下）。
- `asking` 时列表尾部追加一个临时 `AIAnswerBubble`，传入 `streamReasoning` / `streamText`，两者皆空时 `showSpinner` 显示转圈 +「正在思考…」。
- ForEach 键值 `messageRenderKey`：`${id}_${needs_feedback}_${feedback}_${text.length}` —— 反馈后条目才会重建，按钮才会消失（README「ForEach 键值必须包含驱动渲染的字段」）。

### 输入区

- `TextArea` + 「深度思考」「联网搜索」两个 `ToggleChip` + 圆形 `↑` 发送键（有内容点亮 `PRIMARY`，否则 `#C7CEDA`；生成中禁用）。
- `ToggleChip` 为 `@Builder`，**以单个对象字面量 `ToggleChipParams` 传参**（按引用传递，选中态变化才会驱动刷新；多个按值参数不会刷新，见 08-31 文档底栏角标事故）。
- 原「AI 回答可能有误，请核对原始来源」小字移至气泡底部（有 `source` 时展示「内容由 AI 生成，请仔细甄别」）。

## 五、新增组件：`components/business/AIAnswerBubble.ets`

- 白卡（`CARD_BG`）+ 1px `DIVIDER` 边框 + 圆角 16 + 内边距 14。
- `@Prop`：`reasoning` / `text` / `source` / `showSpinner` / `needsFeedback` / `feedback` / `feedbackLocked` / `feedbackBusy`；回调 `onFeedback(satisfied)`；`@State expanded = false`。
- 结构自上而下：「思考过程 / 展开·收起」行（`reasoning` 非空时）→ 展开后的思考正文（13 号灰）→ 正文（`AIText.formatAnswer` 后，15 号 / 行高 22）→ 转圈行 → 来源 + 甄别提示 → 知识库反馈按钮或已反馈文案。
- 同时用于已持久化消息与流式临时气泡；`done` 后临时气泡被持久化消息替换，展开态随之重置为收起（与安卓 `remember(message.id)` 行为一致）。

## 六、路由与清理

- `pages/PageMap.ets`：`'AI'` 路由改为 `AIChatPage({ conversationId: 0, conversationTitle: '' })`；首页「AI 助手」宫格（`HomeTab.ets`）与百宝箱横幅（`ToolsTab.ets`）入口代码无需改动。
- 删除 `pages/AIAssistant.ets`、`components/tabs/AITab.ets`（旧的会话列表 / 模型选择页，已无引用；删除会话能力并入对话记录弹层）。
- README：功能清单、技术要点（新增「SSE 流式」条目）、目录说明同步更新。

## 七、新增 / 修改文件

| 文件 | 类型 | 说明 |
| --- | --- | --- |
| `entry/src/main/ets/service/Http.ets` | 修改 | `streamRequest`、`buildHeaders` |
| `entry/src/main/ets/service/Api.ets` | 修改 | `askAIStream` |
| `entry/src/main/ets/model/Types.ets` | 修改 | `AIMessage.reasoning`、`AIStreamEvent` |
| `entry/src/main/ets/constants/AppConfig.ets` | 修改 | `STREAM_TIMEOUT_MS` |
| `entry/src/main/ets/utils/AIText.ets` | 新增 | Markdown 清洗 |
| `entry/src/main/ets/components/business/AIAnswerBubble.ets` | 新增 | AI 回答气泡 |
| `entry/src/main/ets/components/common/NavBar.ets` | 修改 | 次级右侧文字操作 |
| `entry/src/main/ets/pages/AIChat.ets` | 重写 | 对话页 |
| `entry/src/main/ets/pages/PageMap.ets` | 修改 | `AI` 路由指向对话页 |
| `entry/src/main/ets/pages/AIAssistant.ets` | 删除 | 旧 AI 列表页 |
| `entry/src/main/ets/components/tabs/AITab.ets` | 删除 | 旧 AI 列表组件 |
| `README.md` | 修改 | 功能与技术要点 |

## 八、已知前提与待验证

1. **`requestInStream` 的 promise 决议时机**（响应头到达时还是整个响应结束时）文档未明确，`streamRequest` 对两种情况都做了处理：`requestDone && dataEnded` 同时满足才结束；错误状态额外有 300ms 兜底。真机联调建议故意触发一次 401 / 429（额度用尽）确认错误 toast 正常、页面不挂起。
2. SSE 解析只认 `data:` 行、不做多行 `data:` 拼接，与安卓端一致；后端若改为标准多行 SSE，两端需同步调整。
3. `replacePath('AIChat' → 'AIChat')` 依赖 NavPathStack 为新参数重建 NavDestination 实例（旧版 `newConversation()` 已使用同一方式，行为已验证）。
4. 「深度思考 / 联网搜索」两个开关与安卓端一样仅为本地状态，等后端提供参数后两端一起接入。
5. 会话消息仍依赖 `GET /ai/conversations` 全量返回（含每个会话的全部消息），会话很多时响应体会膨胀，属两端共同的接口层问题。

---

构建命令（本机 DevEco Studio）：

```bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH"
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
