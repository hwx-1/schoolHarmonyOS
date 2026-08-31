import { AppColors } from '../constants/AppConfig';
import { AITab } from '../components/tabs/AITab';

/** AI 校园助手：作为百宝箱内的独立页面（NavDestination），内容由 AITab 承载。 */
@Component
export struct AIAssistantPage {
  build() {
    NavDestination() {
      AITab()
    }
    .hideTitleBar(true)
    .backgroundColor(AppColors.PAGE_BG)
  }
}
