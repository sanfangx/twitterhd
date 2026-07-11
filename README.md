# TweetImageDownloader (Twitter/X 4K 原图抓取与保存 App)

原生 iOS 16+ 现代化应用，使用 **SwiftUI + Swift Concurrency + WKWebView** 构建。专门用于一键提取并保存 Twitter/X 推文中的 4K 高清原图。

---

## 核心特性

1. **智能过滤与原图转换**
   - 只精准匹配推文目标作者发在其主贴及自评连贴下的所有有效配图，自动排除评论区路人网友回复产生的冗杂图片。
   - 自动把 `name=small` / `name=medium` 参数转换为最高画质参数 `name=4096x4096`。
2. **预览迅速，画质拉满**
   - 解析完成后网格展示清晰度适中的预览图，大幅提升界面加载与多选流畅度；
   - 选定并点击下载后，后台自动按 `4096x4096` 原始分辨率直接存入系统相册。
3. **后台常驻 WKWebView 与账号鉴权**
   - 底部第二个 Tab「设置登录」中可一键可视化呼出真实 Twitter/X 网页，方便处理账号登录与人机验证；
   - Cookie 在 `WKWebsiteDataStore` 层面自动持久化，App 重启依然保持有效。
4. **苹果系统级快捷指令 (App Intents)**
   - 深度支持 iOS 16+ 快捷指令系统；
   - 用户可直接在「快捷指令」中调用 `下载推文 4K 原图到相册` Action，轻松同 Safari 分享面板或自动化场景对接。

---

## 项目结构

```
TweetImageDownloader/
├── TweetImageDownloader.xcodeproj/  # 标准 Xcode 原生工程
├── TweetImageDownloader/
│   ├── Info.plist                   # 包含系统相册授权配置
│   ├── App/
│   │   └── TweetImageDownloaderApp.swift
│   ├── Models/
│   │   └── TweetImageItem.swift     # 推文图片模型 (含预览 URL / 4K URL)
│   ├── Services/
│   │   ├── TwitterExtractorJS.swift # WKWebView 页面解析核心 JS 引擎
│   │   ├── TwitterWebViewService.swift # 常驻单例 WKWebView 页面调度器
│   │   └── PhotoLibraryManager.swift   # 相册批量并发下载保存与触觉反馈
│   ├── ViewModels/
│   │   └── DownloaderViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift        # 主 Tab 导航
│   │   ├── MainDownloaderView.swift # 顶栏输入 + 中间多选网格 + 底部全选/下载
│   │   ├── SettingsView.swift       # 鉴权登录与操作说明
│   │   └── LoginWebViewModal.swift  # 后台网页可视化弹窗组件
│   └── Intents/
│       └── ParseAndDownloadIntent.swift # 苹果 App Intents 快捷指令集成
```

---

## 快速运行与体验

1. 使用 Mac 上的 **Xcode 15+** 打开 `TweetImageDownloader.xcodeproj`。
2. 选择 iOS 16.0 及以上模拟器或真机运行。
3. 首次使用建议切换至底部「设置登录」->「登录 Twitter / X 后台网页」完成一次账号登录（解决对私密推文或反爬验证的拦截）。
4. 返回主界面的输入栏粘贴推文 URL，点击“解析”即可一键批量获取并选存原图！
