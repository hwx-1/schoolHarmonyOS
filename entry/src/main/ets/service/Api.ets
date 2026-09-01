import { http } from '@kit.NetworkKit';
import { request } from './Http';
import { AppState } from './AppState';
import {
  AccountResp,
  AIConversation,
  AIConversationResp,
  AIConversationsResp,
  AIModel,
  Announcement,
  AppNotification,
  AskAIBody,
  AskAIResp,
  CampusTool,
  ChangePasswordBody,
  ChangePasswordResp,
  CommentsResp,
  CreateAIConversationBody,
  CreateCommentBody,
  CreateCommentResp,
  CreatePostBody,
  CreatePostResp,
  DirectConversationItem,
  DirectConversationsResp,
  DirectConversationResp,
  ItemsResp,
  LoginBody,
  MarkNotificationsReadBody,
  NotificationsResp,
  Post,
  PostResp,
  PublicSettings,
  RegisterBody,
  SendDirectMessageBody,
  SendDirectMessageResp,
  SmsCodeBody,
  SmsCodeResp,
  StartDirectConversationBody,
  StartDirectConversationResp,
  SubmitVerificationBody,
  UnreadResp,
  UpdateProfileBody,
  VerificationResp,
} from '../model/Types';

/** 与 apps/mobile 相同的 /api/v1 端点封装，全部强类型。 */
export class Api {
  // ---- 认证 ----
  static login(phone: string, password: string): Promise<AccountResp> {
    const body: LoginBody = { phone, password };
    return request<AccountResp>(http.RequestMethod.POST, '/api/v1/auth/login', body);
  }

  static smsCode(phone: string): Promise<SmsCodeResp> {
    const body: SmsCodeBody = { phone, purpose: 'register' };
    return request<SmsCodeResp>(http.RequestMethod.POST, '/api/v1/auth/sms-code', body);
  }

  static register(input: RegisterBody): Promise<AccountResp> {
    return request<AccountResp>(http.RequestMethod.POST, '/api/v1/auth/register', input);
  }

  static logout(): Promise<void> {
    return request<void>(http.RequestMethod.POST, '/api/v1/auth/logout');
  }

  static me(): Promise<AccountResp> {
    return request<AccountResp>(http.RequestMethod.GET, '/api/v1/me');
  }

  // ---- 帖子 ----
  static listPosts(query: string, mineOnly: boolean): Promise<ItemsResp<Post>> {
    const params: string[] = [];
    if (query.length > 0) {
      params.push(`q=${encodeURIComponent(query)}`);
    }
    if (mineOnly) {
      params.push('mine=1');
    }
    const suffix = params.length > 0 ? `?${params.join('&')}` : '';
    return request(http.RequestMethod.GET, `/api/v1/posts${suffix}`);
  }

  static getPost(id: number): Promise<PostResp> {
    return request<PostResp>(http.RequestMethod.GET, `/api/v1/posts/${id}`);
  }

  static async createPost(input: CreatePostBody): Promise<CreatePostResp> {
    const response = await request<CreatePostResp>(http.RequestMethod.POST, '/api/v1/posts', input);
    AppState.publishPostChange();
    return response;
  }

  static async likePost(id: number): Promise<PostResp> {
    const response = await request<PostResp>(http.RequestMethod.POST, `/api/v1/posts/${id}/like`);
    AppState.publishPostChange();
    return response;
  }

  static async bookmarkPost(id: number): Promise<PostResp> {
    const response = await request<PostResp>(http.RequestMethod.POST, `/api/v1/posts/${id}/bookmark`);
    AppState.publishPostChange();
    return response;
  }

  static listComments(postId: number): Promise<CommentsResp> {
    return request<CommentsResp>(http.RequestMethod.GET, `/api/v1/posts/${postId}/comments`);
  }

  static async createComment(postId: number, text: string, parentId?: number): Promise<CreateCommentResp> {
    const body: CreateCommentBody = { text };
    if (parentId !== undefined && parentId > 0) {
      body.parent_id = parentId;
    }
    const response = await request<CreateCommentResp>(
      http.RequestMethod.POST, `/api/v1/posts/${postId}/comments`, body);
    AppState.publishPostChange();
    return response;
  }

  static myBookmarks(): Promise<ItemsResp<Post>> {
    return request(http.RequestMethod.GET, '/api/v1/me/bookmarks');
  }

  // ---- 公告 / 设置 / 百宝箱 ----
  static listAnnouncements(): Promise<ItemsResp<Announcement>> {
    return request(http.RequestMethod.GET, '/api/v1/announcements');
  }

  static publicSettings(): Promise<PublicSettings> {
    return request<PublicSettings>(http.RequestMethod.GET, '/api/v1/settings/public');
  }

  static listTools(): Promise<ItemsResp<CampusTool>> {
    return request(http.RequestMethod.GET, '/api/v1/tools');
  }

  // ---- 我的 ----
  static updateProfile(input: UpdateProfileBody): Promise<AccountResp> {
    return request<AccountResp>(http.RequestMethod.PUT, '/api/v1/me/profile', input);
  }

  static myVerification(): Promise<VerificationResp> {
    return request<VerificationResp>(http.RequestMethod.GET, '/api/v1/me/verification');
  }

  static submitVerification(input: SubmitVerificationBody): Promise<VerificationResp> {
    return request<VerificationResp>(http.RequestMethod.POST, '/api/v1/me/verification', input);
  }

  static changePassword(currentPassword: string, newPassword: string): Promise<ChangePasswordResp> {
    const body: ChangePasswordBody = {
      current_password: currentPassword,
      new_password: newPassword,
    };
    return request<ChangePasswordResp>(http.RequestMethod.POST, '/api/v1/me/password', body);
  }

  static deleteAccount(): Promise<void> {
    return request<void>(http.RequestMethod.DELETE, '/api/v1/me');
  }

  // ---- 通知 ----
  static notifications(): Promise<NotificationsResp> {
    return request<NotificationsResp>(http.RequestMethod.GET, '/api/v1/me/notifications');
  }

  static async markNotificationsRead(ids: number[]): Promise<UnreadResp> {
    const body: MarkNotificationsReadBody = { ids };
    const response = await request<UnreadResp>(
      http.RequestMethod.POST, '/api/v1/me/notifications/read', body);
    AppState.setUnreadCount(response.unread);
    AppState.publishMessageChange();
    return response;
  }

  // ---- 私信 ----
  static listDirectConversations(): Promise<DirectConversationsResp> {
    return request(http.RequestMethod.GET, '/api/v1/direct-conversations');
  }

  static getDirectConversation(id: number): Promise<DirectConversationResp> {
    return request<DirectConversationResp>(
      http.RequestMethod.GET, `/api/v1/direct-conversations/${id}`);
  }

  static async sendDirectMessage(id: number, text: string, system: boolean = false): Promise<SendDirectMessageResp> {
    const body: SendDirectMessageBody = { text, system };
    const response = await request<SendDirectMessageResp>(
      http.RequestMethod.POST, `/api/v1/direct-conversations/${id}/messages`, body);
    AppState.appendDirectMessage(id, response.message, response.unlocked);
    AppState.publishMessageChange();
    return response;
  }

  static async startDirectConversation(userId: number): Promise<StartDirectConversationResp> {
    const body: StartDirectConversationBody = { user_id: userId };
    const response = await request<StartDirectConversationResp>(
      http.RequestMethod.POST, '/api/v1/direct-conversations', body);
    AppState.publishMessageChange();
    return response;
  }

  /** 进入会话后持久化已读：服务端把对方消息置为 read，返回全量私信未读数直接刷新底栏。 */
  static async markDirectConversationRead(id: number): Promise<UnreadResp> {
    const response = await request<UnreadResp>(
      http.RequestMethod.POST, `/api/v1/direct-conversations/${id}/read`);
    AppState.markDirectConversationRead(id, response.unread);
    AppState.publishMessageChange();
    return response;
  }

  // ---- AI 问答 ----
  static aiModels(): Promise<ItemsResp<AIModel>> {
    return request(http.RequestMethod.GET, '/api/v1/ai/models');
  }

  static aiConversations(): Promise<AIConversationsResp> {
    return request<AIConversationsResp>(http.RequestMethod.GET, '/api/v1/ai/conversations');
  }

  static createAIConversation(title: string, model: string): Promise<AIConversationResp> {
    const body: CreateAIConversationBody = {};
    if (title.length > 0) {
      body.title = title;
    }
    if (model.length > 0) {
      body.model = model;
    }
    return request<AIConversationResp>(http.RequestMethod.POST, '/api/v1/ai/conversations', body);
  }

  static askAI(id: number, text: string, model: string): Promise<AskAIResp> {
    const body: AskAIBody = { text };
    if (model.length > 0) {
      body.model = model;
    }
    return request<AskAIResp>(
      http.RequestMethod.POST, `/api/v1/ai/conversations/${id}/messages`, body);
  }
}
