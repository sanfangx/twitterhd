# TweetImageDownloader (Twitter/X 4K 原图抓取与保存 App)


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
