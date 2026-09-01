import { http } from '@kit.NetworkKit';
import {
  Account,
  AccountResp,
  AIConversation,
  AIConversationResp,
  AIConversationsResp,
  AIMessage,
  AIModel,
  Announcement,
  AppNotification,
  AskAIBody,
  AskAIResp,
  CampusTool,
  ChangePasswordResp,
  CommentItem,
  CommentsResp,
  CreateCommentBody,
  CreateCommentResp,
  CreatePostBody,
  CreatePostResp,
  DirectConversationItem,
  DirectConversationsResp,
  DirectConversationResp,
  DirectMessage,
  ItemsResp,
  MarkNotificationsReadBody,
  MyVerification,
  NotificationsResp,
  Post,
  PostResp,
  PublicAccount,
  PublicSettings,
  RegisterBody,
  SendDirectMessageBody,
  SendDirectMessageResp,
  SmsCodeResp,
  SubmitVerificationBody,
  UnreadResp,
  UpdateProfileBody,
  VerificationResp,
} from '../model/Types';

/**
 * 本地 Mock 服务：无后端时用于验证 App 内样式与交互。
 * 由 AppConfig.USE_LOCAL_MOCK 开关控制，数据保存在内存中，
 * 点赞 / 收藏 / 评论 / 发帖等写操作在当前运行会话内生效。
 */

const MOCK_ACCOUNT: Account = {
  id: 1,
  nickname: '沈大同学',
  avatar: '',
  gender: '保密',
  verified: true,
  phone: '13800000000',
  real_name: '',
  student_no: '',
  class_name: '',
  profile_done: false,
  status: 'active',
  created_at: '2026-08-01T10:00:00+08:00',
};

const AUTHOR_LIN: PublicAccount = { id: 2, nickname: '林间晚风', avatar: '', gender: '女', verified: true, badge: 'org' };
const AUTHOR_BEI: PublicAccount = { id: 3, nickname: '北苑干饭人', avatar: '', gender: '男', verified: false };
const AUTHOR_TUAN: PublicAccount = { id: 4, nickname: '校学生会', avatar: '', gender: '保密', verified: true, badge: 'official' };
const AUTHOR_ADMIN: PublicAccount = { id: 5, nickname: '社区管理员', avatar: '', gender: '保密', verified: true, badge: 'admin' };
const MOCK_SELF: PublicAccount = { id: 1, nickname: '沈大同学', avatar: '', gender: '保密', verified: true, badge: 'org' };

function nowIso(): string {
  return new Date().toISOString();
}

let nextPostId = 100;
let nextCommentId = 100;
let nextMessageId = 100;
let nextAiMessageId = 100;
let nextAiConversationId = 10;

let posts: Post[] = [
  {
    id: 1,
    author: AUTHOR_TUAN,
    text: '【置顶】新生入学教育周安排：周一至周五晚 7 点，博文楼各阶梯教室分学院进行，请 2026 级新同学按时参加。',
    images: [],
    tags: ['新生指南', '通知'],
    status: 'published',
    pinned: true,
    likes: 86,
    comments: 2,
    bookmarks: 34,
    liked: false,
    bookmarked: false,
    created_at: '2026-08-28T09:00:00+08:00',
    updated_at: '2026-08-28T09:00:00+08:00',
  },
  {
    id: 6,
    author: AUTHOR_ADMIN,
    text: '【社区公约】友善交流，理性讨论。发布二手交易信息请注明成色与价格，禁止任何形式的广告刷屏，违规将被限流。',
    images: [],
    tags: ['社区公约'],
    status: 'published',
    pinned: false,
    likes: 156,
    comments: 0,
    bookmarks: 51,
    liked: false,
    bookmarked: false,
    created_at: '2026-08-30T09:10:00+08:00',
    updated_at: '2026-08-30T09:10:00+08:00',
  },
  {
    id: 2,
    author: AUTHOR_LIN,
    text: '图书馆三楼的靠窗座位真是自习宝藏位置，下午阳光刚好不刺眼。推荐大家错峰来，早上八点半之前基本都有座。',
    images: [],
    tags: ['图书馆', '自习'],
    status: 'published',
    pinned: false,
    likes: 42,
    comments: 1,
    bookmarks: 18,
    liked: true,
    bookmarked: true,
    created_at: '2026-08-29T15:20:00+08:00',
    updated_at: '2026-08-29T15:20:00+08:00',
  },
  {
    id: 3,
    author: AUTHOR_BEI,
    text: '北苑食堂二楼的麻辣香锅换师傅了？今天去吃感觉味道比上学期好太多，香锅加宽粉yyds！',
    images: [],
    tags: ['食堂', '美食'],
    status: 'published',
    pinned: false,
    likes: 67,
    comments: 0,
    bookmarks: 23,
    liked: false,
    bookmarked: false,
    created_at: '2026-08-29T18:05:00+08:00',
    updated_at: '2026-08-29T18:05:00+08:00',
  },
  {
    id: 4,
    author: AUTHOR_LIN,
    text: '出闲置：九成新《高等数学》同济第七版上下册，笔记工整，30 元打包，图书馆门口自提。',
    images: [],
    tags: ['二手闲置'],
    status: 'published',
    pinned: false,
    likes: 12,
    comments: 0,
    bookmarks: 4,
    liked: false,
    bookmarked: false,
    created_at: '2026-08-30T08:40:00+08:00',
    updated_at: '2026-08-30T08:40:00+08:00',
  },
  {
    id: 5,
    author: MOCK_SELF,
    text: '军训结束啦！十四天晒黑了两个度，但是分列式走过主席台那一刻真的值了。',
    images: [],
    tags: ['军训'],
    status: 'published',
    pinned: false,
    likes: 25,
    comments: 0,
    bookmarks: 7,
    liked: false,
    bookmarked: false,
    created_at: '2026-08-27T20:12:00+08:00',
    updated_at: '2026-08-27T20:12:00+08:00',
  },
];

let comments: CommentItem[] = [
  {
    id: 1,
    post_id: 1,
    author: AUTHOR_LIN,
    text: '请问材料学院是周几晚上？',
    status: 'published',
    deleted: false,
    created_at: '2026-08-28T10:30:00+08:00',
  },
  {
    id: 2,
    post_id: 1,
    author: AUTHOR_TUAN,
    text: '周三晚，博文楼 203，记得带校园卡签到。',
    status: 'published',
    deleted: false,
    created_at: '2026-08-28T11:02:00+08:00',
  },
  {
    id: 3,
    post_id: 2,
    author: AUTHOR_BEI,
    text: '三楼插座多吗？带电脑去方便不',
    status: 'published',
    deleted: false,
    created_at: '2026-08-29T16:00:00+08:00',
  },
];

let announcements: Announcement[] = [
  {
    id: 1,
    title: '2026 年秋季学期开学通知',
    summary: '9 月 1 日正式上课，8 月 30-31 日老生报到注册。',
    body: '各学院：2026 年秋季学期于 9 月 1 日正式上课，老生 8 月 30-31 日报到注册，新生报到时间另行通知。',
    published: true,
    created_at: '2026-08-25T09:00:00+08:00',
  },
  {
    id: 2,
    title: '图书馆暑期延时开放公告',
    summary: '即日起至 9 月 15 日，闭馆时间延长至 22:30。',
    body: '为满足同学自习需求，即日起至 9 月 15 日，图书馆闭馆时间延长至 22:30，三楼自习区全天开放空调。',
    published: true,
    created_at: '2026-08-26T14:00:00+08:00',
  },
  {
    id: 3,
    title: '校园网升级维护通知',
    summary: '9 月 2 日凌晨 0:00-6:00 校园网升级，期间断网。',
    body: '信息中心将于 9 月 2 日凌晨 0:00-6:00 对校园网核心设备进行升级维护，期间全校断网，请提前安排。',
    published: true,
    created_at: '2026-08-29T10:00:00+08:00',
  },
];

let tools: CampusTool[] = [
  { id: 1, name: '教务系统', type: 'link', icon: '📚', url: 'https://jwc.syu.edu.cn', weight: 100, enabled: true },
  { id: 2, name: '图书馆座位', type: 'link', icon: '📖', url: 'https://lib.syu.edu.cn', weight: 90, enabled: true },
  { id: 3, name: '一卡通充值', type: 'link', icon: '💳', url: 'https://ecard.syu.edu.cn', weight: 80, enabled: true },
  { id: 4, name: '校历查询', type: 'link', icon: '📅', url: 'https://www.syu.edu.cn/xl', weight: 70, enabled: true },
  { id: 5, name: '成绩查询', type: 'link', icon: '📊', url: 'https://jwc.syu.edu.cn/cj', weight: 60, enabled: true },
  { id: 7, name: '校车时刻', type: 'link', icon: '🚌', url: '', weight: 55, enabled: true },
  { id: 6, name: '报修平台', type: 'link', icon: '🔧', url: '', weight: 50, enabled: true },
  { id: 8, name: '空闲教室', type: 'link', icon: '🏫', url: '', weight: 45, enabled: true },
];

let notifications: AppNotification[] = [
  {
    id: 1,
    type: 'system',
    title: '欢迎来到沈大社区',
    body: '完善个人资料并通过学生认证，即可解锁发帖、私信等全部功能。',
    read: false,
    created_at: '2026-08-30T09:00:00+08:00',
  },
  {
    id: 2,
    type: 'comment',
    title: '校学生会 回复了你的评论',
    body: '周三晚，博文楼 203，记得带校园卡签到。',
    ref_type: 'post',
    ref_id: 1,
    read: false,
    created_at: '2026-08-28T11:02:00+08:00',
  },
  {
    id: 3,
    type: 'like',
    title: '林间晚风 赞了你的帖子',
    body: '军训结束啦！十四天晒黑了两个度……',
    ref_type: 'post',
    ref_id: 5,
    read: false,
    created_at: '2026-08-28T21:30:00+08:00',
  },
];

let directConversations: DirectConversationItem[] = [
  {
    id: 1,
    other: AUTHOR_LIN,
    unlocked: true,
    messages: [
      {
        id: 1,
        sender_id: 2,
        text: '同学你好，高数书还在吗？',
        system: false,
        status: 'delivered',
        created_at: '2026-08-30T10:00:00+08:00',
      },
      {
        id: 2,
        sender_id: 1,
        text: '在的，今晚七点图书馆门口可以给你',
        system: false,
        status: 'delivered',
        created_at: '2026-08-30T10:05:00+08:00',
      },
    ],
    updated_at: '2026-08-30T10:05:00+08:00',
    unread_count: 1,
  },
  {
    id: 2,
    other: AUTHOR_BEI,
    unlocked: false,
    messages: [
      {
        id: 3,
        sender_id: 3,
        text: '香锅真的假的，明天我也去试试',
        system: false,
        status: 'delivered',
        created_at: '2026-08-29T19:00:00+08:00',
      },
    ],
    updated_at: '2026-08-29T19:00:00+08:00',
    unread_count: 1,
  },
];

let aiConversations: AIConversation[] = [
  {
    id: 1,
    title: '图书馆开放时间',
    model: 'campus-assistant',
    messages: [
      {
        id: 1,
        role: 'user',
        text: '图书馆几点关门？',
        created_at: '2026-08-29T20:00:00+08:00',
      },
      {
        id: 2,
        role: 'assistant',
        text: '即日起至 9 月 15 日，图书馆闭馆时间延长至 22:30，三楼自习区全天开放。',
        source: '图书馆暑期延时开放公告',
        created_at: '2026-08-29T20:00:05+08:00',
      },
    ],
    created_at: '2026-08-29T20:00:00+08:00',
  },
];

let verification: MyVerification | null = null;
let aiRemaining = 20;

function delay(): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(() => {
      resolve();
    }, 250);
  });
}

function findPost(id: number): Post | undefined {
  return posts.find((item: Post) => item.id === id);
}

function queryValue(query: string, key: string): string {
  const pairs = query.split('&');
  for (const pair of pairs) {
    const eq = pair.indexOf('=');
    if (eq > 0 && pair.substring(0, eq) === key) {
      return decodeURIComponent(pair.substring(eq + 1));
    }
  }
  return '';
}

function newAiMessage(role: string, text: string, source: string): AIMessage {
  const message: AIMessage = {
    id: nextAiMessageId++,
    role: role,
    text: text,
    created_at: nowIso(),
  };
  if (source.length > 0) {
    message.source = source;
  }
  return message;
}

/** 本地 Mock 请求入口：路径分发，返回与线上契约一致的数据。 */
export async function mockRequest<T>(method: http.RequestMethod, path: string, body?: object): Promise<T> {
  await delay();
  const qIdx = path.indexOf('?');
  const clean = qIdx >= 0 ? path.substring(0, qIdx) : path;
  const query = qIdx >= 0 ? path.substring(qIdx + 1) : '';
  const segments = clean.split('/').filter((seg: string) => seg.length > 0);

  // ---- 认证 ----
  if (clean === '/api/v1/auth/login' && method === http.RequestMethod.POST) {
    const resp: AccountResp = { account: MOCK_ACCOUNT };
    return resp as T;
  }
  if (clean === '/api/v1/auth/sms-code' && method === http.RequestMethod.POST) {
    const resp: SmsCodeResp = { sent: true, dev_mode: true, dev_code: '8888', expires_in: 300 };
    return resp as T;
  }
  if (clean === '/api/v1/auth/register' && method === http.RequestMethod.POST) {
    const input = body as RegisterBody;
    MOCK_ACCOUNT.nickname = input.nickname.length > 0 ? input.nickname : MOCK_ACCOUNT.nickname;
    MOCK_SELF.nickname = MOCK_ACCOUNT.nickname;
    const resp: AccountResp = { account: MOCK_ACCOUNT };
    return resp as T;
  }
  if (clean === '/api/v1/auth/logout') {
    return undefined as T;
  }
  if (clean === '/api/v1/me' && method === http.RequestMethod.GET) {
    const resp: AccountResp = { account: MOCK_ACCOUNT };
    return resp as T;
  }
  if (clean === '/api/v1/me' && method === http.RequestMethod.DELETE) {
    return undefined as T;
  }

  // ---- 帖子 ----
  if (clean === '/api/v1/posts' && method === http.RequestMethod.GET) {
    const keyword = queryValue(query, 'q');
    const mineOnly = queryValue(query, 'mine') === '1';
    let result = posts;
    if (mineOnly) {
      result = result.filter((item: Post) => item.author.id === MOCK_ACCOUNT.id);
    }
    if (keyword.length > 0) {
      result = result.filter((item: Post) => {
        const inText = item.text.indexOf(keyword) >= 0;
        const inTags = (item.tags ?? []).some((tag: string) => tag.indexOf(keyword) >= 0);
        return inText || inTags;
      });
    }
    const resp: ItemsResp<Post> = { items: result };
    return resp as T;
  }
  if (clean === '/api/v1/posts' && method === http.RequestMethod.POST) {
    const input = body as CreatePostBody;
    const post: Post = {
      id: nextPostId++,
      author: MOCK_SELF,
      text: input.text,
      images: input.images,
      tags: input.tags,
      status: 'published',
      pinned: false,
      likes: 0,
      comments: 0,
      bookmarks: 0,
      liked: false,
      bookmarked: false,
      created_at: nowIso(),
      updated_at: nowIso(),
    };
    posts = [post, ...posts];
    const resp: CreatePostResp = {
      post: post,
      moderation: { pass: true, dev_mode: true },
      message: '发布成功（本地 Mock）',
    };
    return resp as T;
  }
  if (segments.length === 4 && segments[2] === 'posts' && method === http.RequestMethod.GET) {
    const post = findPost(Number(segments[3]));
    const resp: PostResp = { post: post ?? posts[0] };
    return resp as T;
  }
  if (segments.length === 5 && segments[2] === 'posts' && segments[4] === 'like') {
    const post = findPost(Number(segments[3]));
    if (post) {
      post.liked = !post.liked;
      post.likes += post.liked ? 1 : -1;
    }
    const resp: PostResp = { post: post ?? posts[0] };
    return resp as T;
  }
  if (segments.length === 5 && segments[2] === 'posts' && segments[4] === 'bookmark') {
    const post = findPost(Number(segments[3]));
    if (post) {
      post.bookmarked = !post.bookmarked;
    }
    const resp: PostResp = { post: post ?? posts[0] };
    return resp as T;
  }
  if (segments.length === 5 && segments[2] === 'posts' && segments[4] === 'comments'
    && method === http.RequestMethod.GET) {
    const postId = Number(segments[3]);
    const resp: CommentsResp = {
      items: comments.filter((item: CommentItem) => item.post_id === postId),
    };
    return resp as T;
  }
  if (segments.length === 5 && segments[2] === 'posts' && segments[4] === 'comments'
    && method === http.RequestMethod.POST) {
    const postId = Number(segments[3]);
    const input = body as CreateCommentBody;
    const comment: CommentItem = {
      id: nextCommentId++,
      post_id: postId,
      author: MOCK_SELF,
      text: input.text,
      status: 'published',
      deleted: false,
      created_at: nowIso(),
    };
    comments = [...comments, comment];
    const post = findPost(postId);
    if (post) {
      post.comments += 1;
    }
    const resp: CreateCommentResp = {
      comment: comment,
      moderation: { pass: true, dev_mode: true },
      message: '评论成功（本地 Mock）',
    };
    return resp as T;
  }
  if (clean === '/api/v1/me/bookmarks') {
    const resp: ItemsResp<Post> = { items: posts.filter((item: Post) => item.bookmarked) };
    return resp as T;
  }

  // ---- 公告 / 设置 / 百宝箱 ----
  if (clean === '/api/v1/announcements') {
    const resp: ItemsResp<Announcement> = { items: announcements };
    return resp as T;
  }
  if (clean === '/api/v1/settings/public') {
    const resp: PublicSettings = {
      hot_topics: ['新生指南', '图书馆', '食堂', '军训', '二手闲置', '自习'],
      greeting: '欢迎来到沈大社区（本地 Mock 模式）',
    };
    return resp as T;
  }
  if (clean === '/api/v1/tools') {
    const resp: ItemsResp<CampusTool> = { items: tools };
    return resp as T;
  }

  // ---- 我的 ----
  if (clean === '/api/v1/me/profile' && method === http.RequestMethod.PUT) {
    const input = body as UpdateProfileBody;
    MOCK_ACCOUNT.nickname = input.nickname;
    MOCK_ACCOUNT.avatar = input.avatar;
    MOCK_ACCOUNT.gender = input.gender;
    MOCK_ACCOUNT.real_name = input.real_name;
    MOCK_ACCOUNT.student_no = input.student_no;
    MOCK_ACCOUNT.class_name = input.class_name;
    MOCK_ACCOUNT.profile_done = true;
    MOCK_SELF.nickname = input.nickname;
    MOCK_SELF.avatar = input.avatar;
    const resp: AccountResp = { account: MOCK_ACCOUNT };
    return resp as T;
  }
  if (clean === '/api/v1/me/verification' && method === http.RequestMethod.GET) {
    const resp: VerificationResp = { verification: verification };
    return resp as T;
  }
  if (clean === '/api/v1/me/verification' && method === http.RequestMethod.POST) {
    const input = body as SubmitVerificationBody;
    verification = {
      id: 1,
      status: 'pending',
      real_name: input.real_name,
      student_no: input.student_no,
      created_at: nowIso(),
    };
    const resp: VerificationResp = { verification: verification };
    return resp as T;
  }
  if (clean === '/api/v1/me/password' && method === http.RequestMethod.POST) {
    const resp: ChangePasswordResp = { changed: true };
    return resp as T;
  }

  // ---- 通知 ----
  if (clean === '/api/v1/me/notifications' && method === http.RequestMethod.GET) {
    const unread = notifications.filter((item: AppNotification) => !item.read).length;
    const resp: NotificationsResp = { items: notifications, unread: unread };
    return resp as T;
  }
  if (clean === '/api/v1/me/notifications/read' && method === http.RequestMethod.POST) {
    const input = body as MarkNotificationsReadBody;
    notifications = notifications.map((item: AppNotification) => {
      if (input.ids.length > 0 && input.ids.indexOf(item.id) < 0) {
        return item;
      }
      const readItem: AppNotification = {
        id: item.id,
        type: item.type,
        title: item.title,
        body: item.body,
        ref_type: item.ref_type,
        ref_id: item.ref_id,
        read: true,
        created_at: item.created_at,
      };
      return readItem;
    });
    const unread = notifications.filter((item: AppNotification) => !item.read).length;
    const resp: UnreadResp = { unread: unread };
    return resp as T;
  }

  // ---- 私信 ----
  if (clean === '/api/v1/direct-conversations' && method === http.RequestMethod.GET) {
    let unread = 0;
    directConversations.forEach((item: DirectConversationItem) => {
      unread += item.unread_count;
    });
    const resp: DirectConversationsResp = { items: directConversations, unread: unread };
    return resp as T;
  }
  if (segments.length === 4 && segments[2] === 'direct-conversations'
    && method === http.RequestMethod.GET) {
    const id = Number(segments[3]);
    const found = directConversations.find((item: DirectConversationItem) => item.id === id)
      ?? directConversations[0];
    const other: Account = {
      id: found.other.id,
      nickname: found.other.nickname,
      avatar: found.other.avatar,
      gender: found.other.gender,
      verified: found.other.verified,
      profile_done: true,
      status: 'active',
      created_at: '2026-08-01T10:00:00+08:00',
    };
    const resp: DirectConversationResp = {
      conversation: {
        id: found.id,
        messages: found.messages,
        updated_at: found.updated_at,
        unread_count: found.unread_count,
      },
      other: other,
      unlocked: found.unlocked,
    };
    return resp as T;
  }
  if (segments.length === 5 && segments[2] === 'direct-conversations' && segments[4] === 'messages'
    && method === http.RequestMethod.POST) {
    const id = Number(segments[3]);
    const input = body as SendDirectMessageBody;
    const message: DirectMessage = {
      id: nextMessageId++,
      sender_id: MOCK_ACCOUNT.id,
      text: input.text,
      system: input.system,
      status: 'delivered',
      created_at: nowIso(),
    };
    const found = directConversations.find((item: DirectConversationItem) => item.id === id);
    if (found) {
      found.messages = [...found.messages, message];
      found.updated_at = message.created_at;
    }
    const resp: SendDirectMessageResp = { message: message, unlocked: true };
    return resp as T;
  }
  if (segments.length === 5 && segments[2] === 'direct-conversations' && segments[4] === 'read'
    && method === http.RequestMethod.POST) {
    const id = Number(segments[3]);
    const found = directConversations.find((item: DirectConversationItem) => item.id === id);
    if (found) {
      found.messages = found.messages.map((message: DirectMessage) => {
        if (message.sender_id !== MOCK_ACCOUNT.id && message.status === 'delivered') {
          const readMessage: DirectMessage = {
            id: message.id,
            sender_id: message.sender_id,
            text: message.text,
            system: message.system,
            status: 'read',
            created_at: message.created_at,
          };
          return readMessage;
        }
        return message;
      });
      found.unread_count = 0;
    }
    let unread = 0;
    directConversations.forEach((item: DirectConversationItem) => {
      unread += item.unread_count;
    });
    const resp: UnreadResp = { unread: unread };
    return resp as T;
  }

  // ---- AI 问答 ----
  if (clean === '/api/v1/ai/models') {
    const model: AIModel = {
      id: 1,
      name: '校园助手（Mock）',
      model: 'campus-assistant',
      enabled: true,
      public: true,
    };
    const resp: ItemsResp<AIModel> = { items: [model] };
    return resp as T;
  }
  if (clean === '/api/v1/ai/conversations' && method === http.RequestMethod.GET) {
    const resp: AIConversationsResp = { items: aiConversations, remaining: aiRemaining };
    return resp as T;
  }
  if (clean === '/api/v1/ai/conversations' && method === http.RequestMethod.POST) {
    const conversation: AIConversation = {
      id: nextAiConversationId++,
      title: '新会话',
      model: 'campus-assistant',
      messages: [],
      created_at: nowIso(),
    };
    aiConversations = [conversation, ...aiConversations];
    const resp: AIConversationResp = { conversation: conversation };
    return resp as T;
  }
  if (segments.length === 6 && segments[3] === 'conversations' && segments[5] === 'messages'
    && method === http.RequestMethod.POST) {
    const input = body as AskAIBody;
    const userMessage = newAiMessage('user', input.text, '');
    const answer = newAiMessage(
      'assistant',
      `这是本地 Mock 的回答：你问的是「${input.text}」。接入真实后端后，这里会返回校园知识库的真实答案。`,
      '本地模拟数据',
    );
    const id = Number(segments[4]);
    const found = aiConversations.find((item: AIConversation) => item.id === id);
    if (found) {
      found.messages = [...found.messages, userMessage, answer];
    }
    if (aiRemaining > 0) {
      aiRemaining -= 1;
    }
    const resp: AskAIResp = { user_message: userMessage, answer: answer, remaining: aiRemaining };
    return resp as T;
  }

  throw new Error(`本地 Mock 未实现该接口：${method} ${clean}`);
}
