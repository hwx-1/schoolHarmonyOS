import { LoginPage } from './Login';
import { RegisterPage } from './Register';
import { TabsPage } from './Index';
import { PostDetailPage } from './PostDetail';
import { ComposePage } from './Compose';
import { SearchPage } from './Search';
import { AnnouncementsPage } from './Announcements';
import { ToolsPage } from './Tools';
import { AIAssistantPage } from './AIAssistant';
import { ChatPage } from './Chat';
import { AIChatPage } from './AIChat';
import { ContentListPage } from './ContentList';
import { EditProfilePage } from './EditProfile';
import { VerificationPage } from './Verification';
import { AccountSettingsPage } from './AccountSettings';
import { NotificationDetailPage } from './NotificationDetail';
import { NotificationsPage } from './Notifications';
import { LegalDocumentPage } from './LegalDocument';
import { NotificationSettingsPage } from './NotificationSettings';
import { AboutPage } from './About';
import {
  AIChatParam,
  ChatParam,
  ContentListParam,
  LegalDocumentParam,
  NotificationDetailParam,
  PostDetailParam,
  SearchParam,
} from '../model/Types';

/**
 * NavDestination 路由表。
 * 页面跳转统一使用 navStack.pushPath({ name, param })，
 * param 在这里收敛为各页面的强类型入参（类型定义见 model/Types.ets）。
 */
@Builder
export function PageMap(name: string, param: Object | undefined) {
  if (name === 'Login') {
    LoginPage()
  } else if (name === 'Register') {
    RegisterPage()
  } else if (name === 'Tabs') {
    TabsPage()
  } else if (name === 'PostDetail') {
    PostDetailPage({ postId: (param as PostDetailParam).id })
  } else if (name === 'NotificationDetail') {
    NotificationDetailPage({ notification: (param as NotificationDetailParam).notification })
  } else if (name === 'Notifications') {
    NotificationsPage()
  } else if (name === 'LegalDocument') {
    LegalDocumentPage({ documentType: (param as LegalDocumentParam).type })
  } else if (name === 'NotificationSettings') {
    NotificationSettingsPage()
  } else if (name === 'About') {
    AboutPage()
  } else if (name === 'Compose') {
    ComposePage()
  } else if (name === 'Search') {
    SearchPage({ initialKeyword: (param as SearchParam).keyword })
  } else if (name === 'Announcements') {
    AnnouncementsPage()
  } else if (name === 'Tools') {
    ToolsPage()
  } else if (name === 'AI') {
    AIAssistantPage()
  } else if (name === 'Chat') {
    ChatPage({
      conversationId: (param as ChatParam).id,
      otherName: (param as ChatParam).name
    })
  } else if (name === 'AIChat') {
    AIChatPage({
      conversationId: (param as AIChatParam).id,
      conversationTitle: (param as AIChatParam).title
    })
  } else if (name === 'ContentList') {
    ContentListPage({ mode: (param as ContentListParam).mode })
  } else if (name === 'EditProfile') {
    EditProfilePage()
  } else if (name === 'Verification') {
    VerificationPage()
  } else if (name === 'AccountSettings') {
    AccountSettingsPage()
  }
}
