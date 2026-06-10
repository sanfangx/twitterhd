 # TwitterHD
 
 Twitter/X 图片原图下载工具 (iOS)
 
 ## 功能
 
 - **一键下载**：粘贴推文链接，自动提取并下载所有原图
 - **原始画质**：自动获取 `?name=orig` 最高分辨率图片
 - **推文解析**：通过 `__NEXT_DATA__` 提取推文媒体数据
 - **X 登录**：WKWebView 登录 X，Cookie 保存到 Keychain
 - **多图预览**：支持图片缩放手势，左右滑动浏览
 - **下载历史**：Core Data 存储，可按推文浏览已下载图片
 - **自动保存**：默认自动保存到相册，可在设置中切换手动
 - **画质选择**：支持 orig / large / medium 画质切换
 
 ## 环境要求
 
 - iOS 16.0+
 - Xcode 14+
 
 ## 开发环境搭建
 
 1. 克隆仓库：
    ```bash
    git clone https://github.com/sanfangx/twitterhd.git
    ```
 2. 在 Xcode 中打开项目：
    - File → Open → 选择 `TwitterHD` 文件夹
    - 或者新建一个 iOS App 项目，将所有 .swift 文件拖进去
 3. 修改 Bundle Identifier 为你的标识
 4. 选择真机或模拟器运行
 
 > **注意**：因为使用了 `WKWebView` 和 `Keychain`，部分功能需要在真机上测试
 
 ## 技术栈
 
 - Swift + SwiftUI
 - Core Data (程序化模型)
 - WKWebView + Keychain (登录态管理)
 - URLSession (网络请求)
 - PHPhotoLibrary (相册保存)
 
 ## 项目结构
 
 ```
 TwitterHD/
 ├── TwitterHD/
 │   ├── TwitterHDApp.swift          # App 入口
 │   ├── ContentView.swift           # Tab 主视图
 │   ├── Info.plist                  # 应用配置
 │   ├── Models/
 │   │   └── CoreDataModels.swift    # 数据模型
 │   ├── Services/
 │   │   ├── TwitterService.swift    # 推文解析核心
 │   │   ├── AuthService.swift       # X 登录 + Cookie
 │   │   ├── ImageDownloadService.swift # 图片下载
 │   │   └── CoreDataManager.swift   # Core Data 管理
 │   ├── Views/
 │   │   ├── DownloadView.swift      # 下载页
 │   │   ├── HistoryView.swift       # 历史页
 │   │   ├── SettingsView.swift      # 设置页
 │   │   ├── ImagePreviewView.swift  # 图片预览
 │   │   └── LoginView.swift         # 登录页
 │   └── Utilities/
 │       └── Extensions.swift        # 工具扩展
 └── .gitignore
 ```
