import Foundation
import AppIntents

/// 供 iOS 系统快捷指令 (Shortcuts / Siri) 调用的推文原图下载意图
@available(iOS 16.0, *)
public struct DownloadTweetOriginalImagesIntent: AppIntent {
    public static let title: LocalizedStringResource = "下载推文 4K 原图到相册"
    public static let description = IntentDescription("自动在后台解析输入推文目标作者的高清原图并一键保存到系统相册。")
    
    @Parameter(title: "推文链接", description: "例如 https://x.com/.../status/...")
    public var tweetURL: URL
    
    public init() {}
    
    public init(tweetURL: URL) {
        self.tweetURL = tweetURL
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        // 1. 调用后台 WKWebView 服务抓取推文图片
        let items = try await TwitterWebViewService.shared.parseTweetImages(from: tweetURL.absoluteString)
        
        // 2. 批量将 4K 原图写入 iOS 相册
        let count = try await PhotoLibraryManager.shared.saveOriginalImages(items) { completed, total in
            print("快捷指令执行保存进度: \(completed)/\(total)")
        }
        
        return .result(value: count)
    }
}

/// 提供系统级快捷指令注册，便于在“快捷指令” App 和 Spotlight 中即刻使用
@available(iOS 16.0, *)
public struct TweetDownloaderShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: DownloadTweetOriginalImagesIntent(),
                phrases: [
                    "用 \(.applicationName) 下载推文原图",
                    "抓取 \(.applicationName) 推特原图"
                ],
                shortTitle: "下载推特 4K 原图",
                systemImageName: "arrow.down.to.line.circle"
            )
        ]
    }
}
