import Foundation
import WebKit

/// 错误类型定义
public enum TwitterParseError: LocalizedError {
    case invalidURL
    case timeout
    case jsExecutionFailed(String)
    case noImagesFound
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 Twitter/X 推文链接格式"
        case .timeout:
            return "网页加载超时，请检查网络或在「设置」中确认是否需要重新登录"
        case .jsExecutionFailed(let msg):
            return "网页解析异常: \(msg)"
        case .noImagesFound:
            return "未在目标作者推文中解析到图片（请确认作者推文包含配图）"
        }
    }
}

/// 解析结果内部转换结构
private struct JSParseResult: Codable {
    let success: Bool
    let author: String?
    let count: Int?
    let images: [JSImageEntry]?
    let error: String?
}

private struct JSImageEntry: Codable {
    let previewURL: String
    let originalURL: String
    let authorUsername: String
}

/// 后台常驻单例 WKWebView 服务类，同时负责网页登录展示与隐式解析
@MainActor
public final class TwitterWebViewService: NSObject, ObservableObject {
    public static let shared = TwitterWebViewService()
    
    /// 全局共用的后台 WKWebView（使用默认 WebsiteDataStore 保持会话 Cookie，方便持续保持登录态）
    public let webView: WKWebView
    
    @Published public var isLoadingPage: Bool = false
    
    /// 使用 nonisolated(unsafe) 避免在 NavigationDelegate 回调中访问 actor 引发的并发问题
    private var navigationContinuation: CheckedContinuation<Void, Error>?
    /// 防止 continuation 被重复 resume（didFinish + didFail 同时触发时崩溃）
    private var navigationContinuationResumed: Bool = false
    
    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.allowsInlineMediaPlayback = true
        
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        super.init()
        self.webView.navigationDelegate = self
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
    
    /// 解析传入的推文链接中的图片 URL 列表
    public func parseTweetImages(from urlString: String) async throws -> [TweetImageItem] {
        guard let cleanedURL = cleanAndValidateTweetURL(urlString) else {
            throw TwitterParseError.invalidURL
        }
        
        isLoadingPage = true
        defer { isLoadingPage = false }
        
        // 1. 加载目标推文链接页面
        try await loadURL(cleanedURL)
        
        // 2. 自动轮询提取重试循环 (最多尝试 45 次，每次间隔 200ms，合共等候达 9 秒，彻底避免需要手动反复点击解析)
        for attempt in 0..<45 {
            // 如果等待超过 2.5 秒仍未见图片，轻微滚动触发页面可能存在的懒加载
            if attempt == 12 {
                // 安全执行 JS，忽略滚动指令的返回值和任何错误
                await evaluateJavaScriptSafely("window.scrollBy(0, 350);")
            }
            
            if let jsonString = await evaluateJavaScriptSafely(TwitterExtractorJS.extractionScript),
               let jsonData = jsonString.data(using: .utf8),
               let parseResult = try? JSONDecoder().decode(JSParseResult.self, from: jsonData),
               parseResult.success,
               let entries = parseResult.images,
               !entries.isEmpty {
                
                // 转为 Model 对象返回 (默认都不勾选: isSelected = false)
                let items = entries.compactMap { entry -> TweetImageItem? in
                    guard let previewURL = URL(string: entry.previewURL),
                          let originalURL = URL(string: entry.originalURL) else {
                        return nil
                    }
                    return TweetImageItem(
                        previewURL: previewURL,
                        originalURL: originalURL,
                        authorUsername: entry.authorUsername,
                        isSelected: false
                    )
                }
                
                if !items.isEmpty {
                    return items
                }
            }
            
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        
        throw TwitterParseError.noImagesFound
    }
    
    /// 安全包装的 evaluateJavaScript：捕获所有异常，将 JS 返回值安全转为 String 避免强转崩溃
    /// 注意：WKWebView.evaluateJavaScript 的 completionHandler 为可选参数，
    ///       Swift Concurrency 不会自动生成 async 桥接，必须手动用 withCheckedContinuation 包装
    @discardableResult
    private func evaluateJavaScriptSafely(_ script: String) async -> String? {
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if error != nil {
                    // JS 执行出错时静默忽略，交给轮询重试
                    continuation.resume(returning: nil)
                } else {
                    // 安全转换：用 as? 而不是 as! 避免类型不匹配崩溃
                    continuation.resume(returning: result as? String)
                }
            }
        }
    }
    
    /// 加载指定 URL，防止 continuation 被重复 resume
    private func loadURL(_ url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // 重置 resume 保护标志
            self.navigationContinuationResumed = false
            self.navigationContinuation = continuation
            let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15.0)
            self.webView.load(request)
        }
    }
    
    /// 安全地 resume continuation，防止重复调用导致崩溃
    private func resumeNavigationContinuation(with result: Result<Void, Error>) {
        guard !navigationContinuationResumed else { return }
        navigationContinuationResumed = true
        switch result {
        case .success:
            navigationContinuation?.resume()
        case .failure(let error):
            navigationContinuation?.resume(throwing: error)
        }
        navigationContinuation = nil
    }
    
    /// 清理并规范化推文地址
    public func cleanAndValidateTweetURL(_ raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("twitter.com") || trimmed.hasPrefix("x.com") {
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              (host.contains("twitter.com") || host.contains("x.com")),
              url.path.contains("/status/") else {
            return nil
        }
        return url
    }
}

// MARK: - WKNavigationDelegate
extension TwitterWebViewService: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        resumeNavigationContinuation(with: .success(()))
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        resumeNavigationContinuation(with: .failure(error))
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        resumeNavigationContinuation(with: .failure(error))
    }
    
    /// iOS 在内存压力下杀掉 WebKit 渲染进程时触发
    /// 此时 WKWebView 对象仍在内存中但内容为空白，必须主动 reload 恢复
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // 如果当前有正在等待的导航 continuation，先让它以失败结束，避免永久挂起
        resumeNavigationContinuation(with: .failure(TwitterParseError.timeout))
        // 重新加载最后一次的 URL，让 WebView 恢复可用状态
        webView.reload()
    }
}
