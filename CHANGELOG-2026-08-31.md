# 变更说明：顶部栏统一与消息页重构

日期：2026-08-31
范围：HarmonyOS 客户端（entry 模块）
构建验证：hvigor `assembleHap` 全量打包通过（BUILD SUCCESSFUL）

---

# 变更说明（二次）：消息同步链路修复与私信能力补齐

日期：2026-08-31（下午）
范围：HarmonyOS 客户端（entry 模块）+ Go 后端（/Users/zhihu/school/server）
构建验证：hvigor `assembleHap` 通过；`go build ./... && go test ./...` 全部通过

## 一、底栏消息角标修复（根因）

- `pages/Index.ets`：底栏导航项 `@Builder TabItem` 改为**单个对象字面量参数**（`TabItemParams`）按引用传递。
  - 原写法多个按值参数，ArkUI 不随状态刷新 —— 异步拿到未读数后角标仍停留在首次构建的 0，这是"角标不显示"的根因。
  - 中间尝试过 `@Component` 直传 `.tabBar()`，运行时崩溃 `class constructor cannot called without 'new'`（`.tabBar()` 只接受 @Builder），已回退并加注释说明两条约束。
- `service/NotificationSync.ets` 维持 3 秒前台轮询；`Index.ets` 未读基线/新消息 Toast 逻辑不变。

## 二、联调配置与可观测性

- `constants/AppConfig.ets`：`USE_LOCAL_MOCK` 改为 `false`；`API_BASE_URL` 更新为本机局域网地址 `http://10.19.236.131:8080`（换网络环境需用 `ipconfig getifaddr en0` 重新获取）。
- 静默失败补日志（`hilog.error`，TAG 分别为 `TabsPage` / `NotificationSync` / `MessagesTab` / `ChatPage`）：`Index.ets refreshUnread`、`NotificationSync.syncNow`、`MessagesTab.loadAll` 两处、`Chat.ets load` 两处。

## 三、后端修复（/Users/zhihu/school/server）

1. **`updateProfile` JSON 绑定 bug**：内联结构体未写 tag，`real_name` / `student_no` / `class_name` 永远绑定不上 → `profile_done` 永远 false → 用户填完资料也 403 不能发帖/评论/私信。已补 `json:"xxx"` tag。
2. **新增私信已读协议** `POST /api/v1/direct-conversations/:id/read`：把会话中对方已送达消息置为 `read`，返回当前用户全量私信未读数 `{unread}`，已读状态服务端持久化、重新拉取不回弹。

## 四、私信能力补齐（对齐 Web 端）

- `pages/Chat.ets`：未解锁时显示握手区（🔒「回复后解锁自由聊天」+ `回复"{greeting}"` 按钮，以 `system=true` 发送内置招呼），双方各回一条后解锁自由输入框；招呼文案取自 `GET /settings/public`（与 Web 同源）。进入会话即调用已读协议持久化已读。
- `service/Api.ets`：`sendDirectMessage` 增加 `system` 参数；新增 `startDirectConversation`、`markDirectConversationRead`。
- `pages/PostDetail.ets`：作者行右侧新增「私信」按钮（非本人可见），建立/复用会话后进入聊天页，行为对齐 Web 端用户主页。
- `model/Types.ets`：新增 `StartDirectConversationBody` / `StartDirectConversationResp`。

## 五、首页常用工具区自适应

- `components/tabs/HomeTab.ets`：工具 Grid 行数与高度按内容动态计算（`toolRows()`），1 排时高 80 内容自动上移，超过 4 个展开第 2 排（高 170）。

## 六、演示数据脚本

- 新增 `scripts/seed_demo_data.py`：一键注入 7 个认证用户、8 条帖子、对演示主账号（王小雨 `13800000001` / `Demo12345`）的 9 点赞 + 6 评论 + 1 回复 + 3 私信（角标约 19）；真实测试账号（`13158268668` / `Test12345`）收到 2 条未读私信。后端重启后重跑即可恢复（有幂等保护）。

## 七、已知前提

- 后端为内存存储，重启后数据清空（种子账号 `13800000000/1/2`，密码 `Demo12345` 随启动自动重建）。
- 互动通知已读链路（`POST /me/notifications/read`）经 curl 按 App 相同请求方式（Cookie + X-CSRF-Token）验证生效。

---

# 变更说明（三次）：消息页改为抖音私信模式

日期：2026-08-31（傍晚）
范围：HarmonyOS 客户端（entry 模块）
构建验证：hvigor `assembleHap` 通过

- `components/tabs/MessagesTab.ets`：重构为「聚合入口 + 独立会话卡片」结构。
  - 顶部「互动通知」入口卡片：铃铛图标 + 红色未读冒泡（`@StorageProp xsnbb_unread_count` 实时刷新）+ 最新一条通知标题预览 + 右箭头，点击才进入通知列表；通知未读的「全部已读」入口随之迁出本页。
  - 下方每个私信会话各为一张独立卡片（`ConversationItemView`），进入会话仍先本地置读、由聊天页已读协议持久化。
- 新增 `pages/Notifications.ets`：互动通知列表页（路由 `Notifications`，已注册进 `PageMap.ets`）。承接原消息页的通知加载/单条已读（乐观更新+失败回滚）/全部已读逻辑，列表统一按时间倒序（服务端 map 遍历顺序不稳定），空态「暂无通知」，支持下拉刷新，点条目进 `NotificationDetail`。
- `components/business/ConversationItemView.ets`：未读数冒泡从头像右上角移到卡片右侧、时间下方，移除右侧 `›`；未读数改由 `MessagesTab` 计算后以原始 number 传入（`unreadOfConversation`），避免 `@Prop` 对象深拷贝在 ForEach 同 key 复用下刷新不及时导致的冒泡残留。
- `MessagesTab.NoticeEntry`：同样移除 `›`，未读数冒泡改为固定在卡片右侧（图标不再叠角标）。

---

# 变更说明（四次）：抖音式两级评论回复

日期：2026-08-31（傍晚）
范围：HarmonyOS 客户端（entry 模块）
构建验证：hvigor `assembleHap` 通过

- `components/business/CommentItemView.ets`：支持回复交互。新增 `isReply`（回复条目：24 小头像、更紧凑）、`replyToName`（回复另一条回复时昵称后带「回复 @对方」）、`onReply` 回调；每条未删除评论的时间旁新增「回复」入口。
- `pages/PostDetail.ets`：评论区重构为抖音式两级结构——
  - 主评论平铺；全部回复（含回复的回复）扁平归属到根评论下，缩进 42 展示；
  - 默认只显示前 2 条回复，超过显示「展开 N 条回复 ⌄」，展开后可「收起回复 ∧」；
  - 点「回复」输入框进入回复模式：上方出现「回复 @昵称：×」指示条、占位文案同步切换，发送携带 `parent_id`（取被回复评论的 id，保证后端只通知被回复者），发送成功自动退出回复模式；
  - 展示分组按根评论聚合（`rootIdOf` 沿 parent_id 上溯），回复的回复带「回复 @对方」前缀。
- `service/Api.ets` / `model/Types.ets`：`createComment` 增加可选 `parentId`，`CreateCommentBody` 增加 `parent_id`。
- 演示数据：帖子 id=2 下补充 3 条回复 + 1 条二级回复，可直接演示折叠展开与「回复 @对方」。
- 整卡点击激活回复（傍晚追加）：`CommentItemView` 移除「回复」文字上的单独点击（文字保留作视觉提示），改为整行 `.onClick` 触发 `onReply`（已删除评论不可点）；`PostDetail.startReply` 进入回复模式后延迟一帧调用 `getUIContext().getFocusController().requestFocus('commentInput')` 自动聚焦输入框并唤起键盘（输入框已加 `.key('commentInput')`）。注：本机 SDK 6.1.0(23) 的 `@kit.ArkUI` 不再导出 `focusControl`，须走 `UIContext.getFocusController()`。
- 键盘自动收起（傍晚追加二）：`PostDetail.sendComment` 发送成功、以及 `cancelReply` 点「×」取消回复时，调用 `getUIContext().getFocusController().clearFocus()` 收起输入法；回复模式占位文案「回复 @昵称：」在上一轮已是抖音样式，保持不变。

---

# 变更说明（五次）：互动按钮只保留数字

日期：2026-08-31（傍晚）
范围：HarmonyOS 客户端（entry 模块）
构建验证：hvigor `assembleHap` 通过

- `components/business/PostCard.ets`（信息流卡片操作栏）：点赞按钮文案「赞同 N / 已赞同 N」→ 仅数字 `N`（已赞仍高亮主色）；评论按钮「N 条评论」→ 仅数字 `N`；收藏按钮去掉文字（数据模型暂无收藏总数），仅保留星形图标，已收藏仍为橙色高亮。
- `pages/PostDetail.ets`（帖子详情操作行）：点赞「赞同 N / 已赞同 N」→ 仅数字 `N`；收藏「收藏 / 已收藏」文字移除，仅保留星形图标（橙色=已收藏）。
- 点赞/收藏的操作结果仍有 Toast 反馈（「已收藏」「已取消收藏」等），图标高亮状态不变。

---

# 变更说明（六次）：收藏计数数据与展示

日期：2026-08-31（傍晚）
范围：Go 后端（/Users/zhihu/school/server）+ HarmonyOS 客户端（entry 模块）
构建验证：`go build ./... && go test ./...` 全部通过；hvigor `assembleHap` 通过；curl 验证切换收藏计数 9→10→9 正确

- 后端 `app/models.go`：`Post` 新增 `bookmarks` 字段（JSON `bookmarks`），随帖子全量下发。
- 后端 `app/store.go`：`ToggleBookmarkLocked` 维护收藏计数（取消时 floor 0，与点赞同风格）；3 条种子帖子预置收藏数（12 / 3 / 9）。
- 前端 `model/Types.ets`：`Post` 接口新增 `bookmarks: number`；`service/Mock.ets` 全部 7 处帖子字面量补齐该字段。
- `components/business/PostCard.ets`、`pages/PostDetail.ets`：收藏星形图标旁显示收藏数（已收藏橙色高亮）。
- `components/tabs/HomeTab.ets`：`toggleLikeSnapshot` / `toggleBookmarkSnapshot` 乐观更新带上收藏数（收藏切换时本地 ±1）。
- `pages/PostDetail.ets`：`sendComment` 手工构造的 Post 字面量补 `bookmarks`。
- `components/tabs/HomeTab.ets`、`pages/Search.ets`：「收藏」排序从「我已收藏优先 + 时间」改为按真实收藏总数倒序。
- 后端已重启（内存数据重置），`scripts/seed_demo_data.py` 已重跑恢复演示数据。

---


## 一、新增：通用微信风格顶部栏 NavBar

新增文件：`entry/src/main/ets/components/common/NavBar.ets`

- 标题始终居中（左右各留 72 安全边距，长标题自动省略，不与两侧按钮重叠）。
- 纯参数驱动（不使用 `@BuilderParam`），支持：
  - `title` / `subtitle`（标题下方副标题，如"今日剩余 N 次"）
  - `titleTag`（标题旁小标签，如私信页"自由聊"）
  - 左侧：返回箭头（`showBack` + `onBack`）或文字按钮（`leftText` + `onLeft`，如"取消"）
  - 右侧：文字按钮（`rightText`，支持字号/颜色/置灰）或实心按钮（`rightButtonText`，如"+ 新会话"）
- 高度自适应（最小 48），带副标题时自动撑高。

### 接入 NavBar 的页面（标题统一居中）

| 页面 | 文件 | 说明 |
| --- | --- | --- |
| 消息 | `components/tabs/MessagesTab.ets` | 居中"消息"，右侧"全部已读" |
| 首页 | `components/tabs/HomeTab.ets` | 新增居中"沈大社区"标题栏 |
| 百宝箱 | `components/tabs/ToolsTab.ets` | 新增居中"百宝箱"标题栏 |
| AI 校园助手 | `components/tabs/AITab.ets` | 居中标题+剩余次数副标题，右侧"+ 新会话" |
| 通知详情 | `pages/NotificationDetail.ets` | 居中"通知详情" |
| 帖子详情 | `pages/PostDetail.ets` | 居中"帖子详情" |
| 私信 | `pages/Chat.ets` | 居中昵称+"自由聊"标签 |
| 校园公告 | `pages/Announcements.ets` | 居中"校园公告" |
| 校园百宝箱 | `pages/Tools.ets` | 居中"校园百宝箱" |
| 消息通知设置 | `pages/NotificationSettings.ets` | 居中"消息通知设置" |
| 学生认证 | `pages/Verification.ets` | 居中"学生认证" |
| 关于 | `pages/About.ets` | 居中"关于沈大社区" |
| 法律文档 | `pages/LegalDocument.ets` | 居中文档标题 |
| 账号设置 | `pages/AccountSettings.ets` | 居中"账号设置" |
| 我的帖子/收藏 | `pages/ContentList.ets` | 居中动态标题 |
| AI 对话 | `pages/AIChat.ets` | 居中会话标题+副标题，右侧新建对话 |
| 编辑资料 | `pages/EditProfile.ets` | 取消 / 居中标题 / 保存 |
| 发布动态 | `pages/Compose.ets` | 取消 / 居中标题 / 发布 |

未改动：搜索页（顶部为搜索框）、登录/注册页（无标题栏设计）、"我的"页（无标题文字）。

## 二、内容顶部对齐修复

以下页面的 `Scroll` 增加 `.align(Alignment.Top)`，修复短内容在可视区垂直居中、而不是从顶部开始展示的问题：

`NotificationDetail`、`About`、`LegalDocument`、`AccountSettings`、`NotificationSettings`、`Verification`、`EditProfile`、`Compose`（`Register` 原本已对齐，`Login` 居中属设计保留）。

## 三、消息页重构（MessagesTab）

- 取消"通知 / 私信"分段页签，统一为一个列表直接展示：上方"私信"区（会话卡片），下方"通知"区（通知卡片），分区仅一行小灰字标签；全部为空时显示"暂无消息"。
- 移除"赞同收藏 / 评论回复 / 系统通知"三个模块卡片及其筛选逻辑。
- 三个模块卡片与"最新通知"标题曾移入列表内部，下拉刷新指示器位于标题栏正下方（页面顶部），当前列表整体即刷新区域。
- 顶部居中"消息"标题，有未读时右侧显示"全部已读"。
- 通知卡片（`NotificationItemView.ets`）移除右下角"查看详情 ›"，整卡点击仍可跳转。

## 四、数字未读冒泡（微信风格）

- 通知卡片：标题右侧小红点 → 红色数字胶囊（未读显示 `1`）。
- 私信会话卡片：头像右上角新增红色未读数胶囊（对方发来且未读的消息条数），超过 99 显示 `99+`，无未读不显示。
- 底部导航"消息"：数字冒泡，`99+` 封顶，未读清零自动消失。
- 即时更新：点开通知前先本地减未读并同步底栏（失败回滚）；进入会话瞬间本地将该会话对方消息置为已读，冒泡立即消失，不延迟。
- 已知前提：私信未读数基于消息 `status` 字段客户端计算，依赖服务端在拉取会话后正确维护已读状态。

## 五、登录后不再弹消息 Toast

`pages/Index.ets`：进入主界面后的首次未读同步只建立基线，直接体现为底栏数字冒泡；之后前台收到新消息才轻提示（仍受"消息通知设置 → 应用内新消息提醒"开关控制）。

## 六、移除未使用的分类通知页

- 删除 `pages/NotificationList.ets`
- 移除 `pages/PageMap.ets` 中的 import 与 `NotificationList` 路由
- 移除 `model/Types.ets` 中的 `NotificationListParam`

## 七、崩溃修复记录

1. **`TypeError: undefined is not callable`**（AITab.ets / NotificationList.ets）：父组件 `@Builder` 方法经 `@BuilderParam` 传入子组件后 `this` 被重绑定到子组件实例，方法调用落空。修复：NavBar 改为纯参数驱动，回调一律用箭头函数传入。
2. **首页/百宝箱/消息页整页空白、标题居中于屏幕**：NavBar 内操作区 `Row` 的 `.height('100%')` 在内容定高的 `Stack` 中反向撑满父容器。修复：移除百分比高度，`Stack` 高度由内容决定。

---

构建命令（本机 DevEco Studio）：

```bash
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```
