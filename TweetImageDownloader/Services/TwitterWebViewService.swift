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
            return "网页加载超时，请检查网络或在“设置”中确认是否需要重新登录"
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
    
    private var navigationContinuation: CheckedContinuation<Void, Error>?
    
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
        
        // 2. 高频短间隔轮询等待推文卡片与图片元素生成（150ms/次，极速侦测）
        try await waitForTweetCardElement(maxAttempts: 35, delayMilliseconds: 150)
        
        // 3. 执行 JS 提取逻辑
        guard let jsonString = try await webView.evaluateJavaScript(TwitterExtractorJS.extractionScript) as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            throw TwitterParseError.jsExecutionFailed("返回值解析失败")
        }
        
        let parseResult = try JSONDecoder().decode(JSParseResult.self, from: jsonData)
        guard parseResult.success else {
            throw TwitterParseError.jsExecutionFailed(parseResult.error ?? "未知错误")
        }
        
        guard let entries = parseResult.images, !entries.isEmpty else {
            throw TwitterParseError.noImagesFound
        }
        
        // 4. 转为 Model 对象返回
        let items = entries.compactMap { entry -> TweetImageItem? in
            guard let previewURL = URL(string: entry.previewURL),
                  let originalURL = URL(string: entry.originalURL) else {
                return nil
            }
            return TweetImageItem(
                previewURL: previewURL,
                originalURL: originalURL,
                authorUsername: entry.authorUsername,
                isSelected: true
            )
        }
        
        if items.isEmpty {
            throw TwitterParseError.noImagesFound
        }
        
        return items
    }
    
    /// 加载指定 URL
    private func loadURL(_ url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.navigationContinuation = continuation
            let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15.0)
            self.webView.load(request)
        }
    }
    
    /// 等待页面出现推文卡片容器或配图元素
    private func waitForTweetCardElement(maxAttempts: Int, delayMilliseconds: UInt64) async throws {
        for _ in 0..<maxAttempts {
            let checkJS = "(document.querySelectorAll('img[src*=\"twimg.com/media/\"]').length > 0) || (document.querySelectorAll('[data-testid=\"cellInnerDiv\"]').length > 0)"
            if let found = try? await webView.evaluateJavaScript(checkJS) as? Bool, found {
                // 仅等待 150ms 确保页面配图列表稳定
                try? await Task.sleep(nanoseconds: 150_000_000)
                return
            }
            try await Task.sleep(nanoseconds: delayMilliseconds * 1_000_000)
        }
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
        navigationContinuation?.resume()
        navigationContinuation = nil
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }
}
