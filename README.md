# xsnbb 鸿蒙端（HarmonyOS）

沈阳大学校园社区的 HarmonyOS 原生客户端，ArkTS + ArkUI 声明式开发，
Stage 模型（UIAbility），compatibleSdkVersion 5.0.0(12)，与仓库内 Go API 对接。

## 已实现功能（与 apps/mobile 对齐）

- 手机号登录 / 注册（短信验证码 + 邀请码，开发模式验证码直接回显）
- 首页信息流：问候语、公告摘要、热门话题、帖子卡片、下拉刷新
- 帖子详情：九宫格图片、标签、点赞 / 收藏、评论列表与发表评论（含内容审核拦截提示）
- 发布动态：文字 + 最多 9 张相册图片（复制进缓存目录后 multipart 上传）+ 最多 3 个话题标签
- 搜索（关键词 / 话题标签）、校园公告（展开全文）、校园百宝箱（openLink 打开外链）
- 消息：系统通知（未读数 / 一键已读）、私信会话列表与聊天（含「自由聊」状态、前台实时接收新消息）
- AI 校园助手：会话列表、剩余次数、新建会话、问答（含知识库来源标注）
- 我的：资料卡与完整度、编辑资料、学生认证（材料上传）、修改密码、注销账号、退出登录

## 技术要点

- **严格 ArkTS**：无 `any`；JSON 反序列化统一收敛在 `utils/Json.ets` 做一次类型收敛，
  业务代码全部面向 `model/Types.ets` 中的强类型契约
- **路由**：Navigation + NavPathStack（`pages/Main.ets` 为唯一 @Entry 根容器，
  `pages/PageMap.ets` 为 NavDestination 路由表，参数类型定义在 `model/Types.ets`），
  未使用已废弃的 router 页面路由
- **反馈**：Toast / 对话框统一走 `UIContext.getPromptAction()`（showToast / showDialog），
  未使用废弃的全局 `promptAction` / `AlertDialog`
- **不可变状态更新**：`@State` 数组 / 对象一律整体替换，不原地修改嵌套字段
- **ForEach 键值必须包含驱动渲染的字段**：ArkUI 在键值不变时复用子组件、不重新执行
  itemGenerator，`@Prop` 与内联闭包会一直持有首次构建的旧对象。列表项内容可变
  （未读数、点赞数、已读态、消息预览、回复数等）时，键值必须把这些字段拼进去，
  例如 `(item) => \`${item.id}:${item.unread_count}\``；仅当条目内容永不变化
  （公告、百宝箱等静态配置）或纯追加且新条目必有新 id（聊天消息）时才允许只用 id。
  反例：2026-09 消息页键值只用会话 id，导致已读后未读冒泡不消失、新消息预览不刷新
- **鉴权**：服务端为 Cookie 会话；`service/Http.ets` 内置 CookieJar，
  自动捕获 Set-Cookie、携带 Cookie，非 GET 请求自动附加 `X-CSRF-Token`
- **长列表**：首页信息流使用 `LazyForEach + BasicDataSource` 按需加载与刷新
- **深色模式**：`resources/dark/element/color.json` 覆盖基础配色

## 目录结构

```
apps/harmony/
├── AppScope/                 # 应用级配置与图标
├── entry/src/main/
│   ├── ets/
│   │   ├── entryability/     # EntryAbility（Stage 模型）
│   │   ├── pages/            # 14 个页面（@Entry）
│   │   ├── components/       # common 通用组件 / business 业务组件 / tabs 主 Tab
│   │   ├── service/          # Http（Cookie/CSRF/上传）、Api（端点封装）、Session
│   │   ├── model/            # 与 /api/v1 对应的类型契约
│   │   ├── utils/            # Json、TimeUtil、BasicDataSource
│   │   └── constants/        # 接口地址与设计基线色值
│   ├── resources/            # 字符串 / 颜色 / 图标 / 页面清单 / 网络安全配置
│   └── module.json5          # 模块配置（INTERNET 权限、cleartext 放行 localhost）
└── build-profile.json5
```

## 本地构建与运行

前置：已安装 DevEco Studio（自带 HarmonyOS SDK 与 hvigor 构建工具）。

```bash
# 1. 启动后端 API（先回到仓库根目录）
corepack pnpm dev:server

# 2. 构建鸿蒙 HAP（未签名 debug 包）
corepack pnpm build:harmony
# 产物：apps/harmony/entry/build/default/outputs/default/entry-default-unsigned.hap
```

真机 / 模拟器运行：

1. 用 DevEco Studio 打开 `apps/harmony/` 目录；
2. 修改 `entry/src/main/ets/constants/AppConfig.ets` 中的 `API_BASE_URL`：
   模拟器 / 真机请改为电脑局域网 IP（如 `http://192.168.x.x:8080`），
   预览器（Previewer）可用默认 `http://127.0.0.1:8080`；
3. 连接设备后 Run，或签名后用 `hdc install` 安装上一步的 HAP。

内置演示账号：手机 `13800000000` / 密码 `Demo12345`；注册邀请码默认 `xsnbb-test`。

## 说明

- 构建产物为**未签名** HAP；上架前需在 DevEco 中配置签名证书、正式图标与隐私说明。
- `build-profile.json5` 未显式设置 `targetSdkVersion`（构建时仅告警），
  正式发布前建议按目标机型系统版本补齐。
