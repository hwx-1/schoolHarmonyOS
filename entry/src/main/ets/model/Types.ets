/** 与服务端 /api/v1 契约严格对应的数据模型。 */

export interface PublicAccount {
  id: number;
  nickname: string;
  avatar: string;
  gender: string;
  verified: boolean;
  /** 徽标类型：official=官方(红) org=认证机构(蓝) admin=管理员发布(绿) */
  badge?: string;
}

export interface Account {
  id: number;
  nickname: string;
  avatar: string;
  gender: string;
  verified: boolean;
  badge?: string;
  phone?: string;
  real_name?: string;
  student_no?: string;
  class_name?: string;
  profile_done: boolean;
  status: string;
  created_at: string;
}

export interface Post {
  id: number;
  author: PublicAccount;
  text: string;
  images: string[] | null;
  tags: string[] | null;
  status: string;
  pinned: boolean;
  likes: number;
  comments: number;
  bookmarks: number;
  liked: boolean;
  bookmarked: boolean;
  created_at: string;
  updated_at: string;
}

export interface CommentItem {
  id: number;
  post_id: number;
  parent_id?: number;
  author: PublicAccount;
  text: string;
  image?: string;
  status: string;
  deleted: boolean;
  created_at: string;
}

export interface Announcement {
  id: number;
  title: string;
  summary: string;
  body: string;
  image_url?: string;
  link_url?: string;
  link_text?: string;
  published: boolean;
  created_at: string;
  updated_at?: string;
  published_at?: string;
}

export interface CampusTool {
  id: number;
  name: string;
  type: string;
  icon: string;
  url?: string;
  weight: number;
  enabled: boolean;
}

export interface AppNotification {
  id: number;
  type: string;
  title: string;
  body: string;
  ref_type?: string;
  ref_id?: number;
  read: boolean;
  created_at: string;
}

export interface DirectMessage {
  id: number;
  sender_id: number;
  text: string;
  system: boolean;
  status: string;
  created_at: string;
}

export interface DirectConversationItem {
  id: number;
  other: PublicAccount;
  unlocked: boolean;
  messages: DirectMessage[];
  updated_at: string;
  unread_count: number;
}

export interface DirectConversationsResp {
  items: DirectConversationItem[];
  unread: number;
}

export interface PublicSettings {
  hot_topics: string[];
  greeting: string;
}

export interface ModerationInfo {
  pass: boolean;
  category?: string;
  reason?: string;
  dev_mode: boolean;
}

export interface AIModel {
  id: number;
  name: string;
  model: string;
  enabled: boolean;
  public: boolean;
}

export interface AIMessage {
  id: number;
  role: string;
  text: string;
  /** 模型给出最终答案前的思考过程（流式 reasoning_content）。 */
  reasoning?: string;
  model?: string;
  source?: string;
  needs_feedback?: boolean;
  feedback?: string;
  created_at: string;
}

/** SSE 流式回答事件：type = thinking / text / done / error。 */
export interface AIStreamEvent {
  type: string;
  delta?: string;
  message?: string;
  user_message?: AIMessage;
  answer?: AIMessage;
  remaining?: number;
}

export interface Appeal {
  id: number;
  punishment_id: number;
  account_id: number;
  kind: string;
  reason: string;
  status: string;
  result?: string;
  created_at: string;
  resolved_at?: string;
}

export interface AIConversation {
  id: number;
  title: string;
  model: string;
  messages: AIMessage[];
  created_at: string;
}

export interface MyVerification {
  id: number;
  status: string;
  reject_reason?: string;
  real_name: string;
  student_no: string;
  created_at: string;
}

/** ---- 请求体 ---- */

export interface LoginBody {
  phone: string;
  password: string;
}

export interface RegisterBody {
  phone: string;
  code: string;
  password: string;
  nickname: string;
  invite_code: string;
}

export interface SmsCodeBody {
  phone: string;
  purpose: string;
}

export interface ResetPasswordBody {
  phone: string;
  code: string;
  password: string;
}

export interface UpdateProfileBody {
  nickname: string;
  avatar: string;
  gender: string;
  real_name: string;
  student_no: string;
  class_name: string;
}

export interface SubmitVerificationBody {
  material_url: string;
  real_name: string;
  student_no: string;
}

export interface ChangePasswordBody {
  current_password: string;
  new_password: string;
}

export interface CreatePostBody {
  text: string;
  images: string[];
  tags: string[];
}

export interface CreateCommentBody {
  text: string;
  image?: string;
  parent_id?: number;
}

export interface ReportBody {
  reason: string;
}

export interface MarkNotificationsReadBody {
  ids: number[];
}

export interface SendDirectMessageBody {
  text: string;
  system: boolean;
}

export interface StartDirectConversationBody {
  user_id: number;
}

export interface StartDirectConversationResp {
  item: DirectConversationItem;
}

export interface CreateAIConversationBody {
  title?: string;
  model?: string;
}

export interface AskAIBody {
  text: string;
  model?: string;
}

export interface AIFeedbackBody {
  satisfied: boolean;
}

export interface CreateAppealBody {
  punishment_id: number;
  reason: string;
}

/** ---- 响应包装 ---- */

export interface ApiErrorPayload {
  code?: string;
  message?: string;
}

export interface ApiErrorBody {
  error?: ApiErrorPayload;
}

export interface AccountResp {
  account: Account;
}

export interface SmsCodeResp {
  sent: boolean;
  dev_mode: boolean;
  dev_code?: string;
  expires_in: number;
}

export interface ResetPasswordResp {
  reset: boolean;
}

export interface ItemsResp<T> {
  items: T[];
}

export interface PostResp {
  post: Post;
}

export interface PublicUserResp {
  user: PublicAccount;
  posts: Post[];
}

export interface AnnouncementResp {
  announcement: Announcement;
}

export interface MessageResp {
  message: string;
}

export interface CreatePostResp {
  post: Post;
  moderation: ModerationInfo;
  message: string;
}

export interface UpdatePostResp {
  post: Post;
  message: string;
}

export interface CommentsResp {
  items: CommentItem[];
}

export interface CreateCommentResp {
  comment: CommentItem;
  moderation: ModerationInfo;
  message: string;
}

export interface VerificationResp {
  verification: MyVerification | null;
}

export interface ChangePasswordResp {
  changed: boolean;
}

export interface NotificationsResp {
  items: AppNotification[];
  unread: number;
}

export interface UnreadResp {
  unread: number;
}

export interface DirectConversationResp {
  conversation: DirectConversationDetail;
  other: Account;
  unlocked: boolean;
}

export interface DirectConversationDetail {
  id: number;
  messages: DirectMessage[];
  updated_at: string;
  unread_count: number;
}

export interface SendDirectMessageResp {
  message: DirectMessage;
  unlocked: boolean;
}

export interface AIConversationsResp {
  items: AIConversation[];
  remaining: number;
}

export interface AIConversationResp {
  conversation: AIConversation;
}

export interface AskAIResp {
  user_message: AIMessage;
  answer: AIMessage;
  remaining: number;
}

export interface AIFeedbackResp {
  message?: AIMessage;
  answer?: AIMessage;
  remaining: number;
}

export interface SubmitAppealResp {
  submitted: boolean;
}

export interface UploadResp {
  url: string;
  dev_mode: boolean;
}

/** ---- Navigation 路由参数 ---- */

export interface PostDetailParam {
  id: number;
}

export interface ComposeParam {
  id: number;
}

export interface PublicProfileParam {
  id: number;
}

export interface ReportParam {
  targetType: string;
  targetId: number;
  targetName: string;
}

export interface VerificationParam {
  onboarding: boolean;
}

export interface NotificationDetailParam {
  notification: AppNotification;
}

export interface LegalDocumentParam {
  type: string;
}

export interface SearchParam {
  keyword: string;
}

export interface ChatParam {
  id: number;
  name: string;
}

export interface AIChatParam {
  id: number;
  title: string;
}

export interface ContentListParam {
  mode: string;
}

export interface AppealsParam {
  punishmentId: number;
}
