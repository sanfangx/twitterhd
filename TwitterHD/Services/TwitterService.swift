 import Foundation
 
 // MARK: - 数据模型
 
 struct TweetInfo {
     let tweetId: String
     let username: String
     let displayName: String?
     let tweetText: String?
     let createdAt: Date
     let images: [ImageInfo]
 }
 
 struct ImageInfo {
     let url: URL
     let width: Int
     let height: Int
 }
 
 // MARK: - TwitterService
 
 actor TwitterService {
     static let shared = TwitterService()
     private init() {}
     
     private let session: URLSession = {
         let config = URLSessionConfiguration.ephemeral
         config.httpShouldSetCookies = true
         config.httpCookieAcceptPolicy = .always
         // 模拟正常浏览器 UA，避免被拒
         config.httpAdditionalHeaders = [
             "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
             "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
             "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
         ]
         return URLSession(configuration: config)
     }()
     
     /// 从链接提取 tweet ID
     func extractTweetId(from url: String) -> String? {
         // 匹配 x.com/xxx/status/1234567890 或 twitter.com/xxx/status/1234567890
         let patterns = [
             #"https?://(x|twitter)\.com/\w+/status/(\d+)"#,
             #"status/(\d+)"#,
         ]
         for pattern in patterns {
             if let match = url.range(of: pattern, options: .regularExpression) {
                 let matched = String(url[match])
                 let parts = matched.split(separator: "/")
                 if let id = parts.last { return String(id) }
             }
         }
         return nil
     }
     
    /// 获取推文信息
    func fetchTweet(url tweetUrl: String) async throws -> TweetInfo {
        // 1. syndication API（最快）
        if let result = try? await fetchViaSyndication(url: tweetUrl) {
            return result
        }
        // 2. 解析推文页面 HTML
        if let result = try? await fetchViaPage(url: tweetUrl) {
            return result
        }
        // 3. WKWebView + 读 DOM（最可靠，但最慢）
        return try await fetchViaWebView(url: tweetUrl)
    }
    
    /// 通过隐藏 WKWebView + JS 注入获取图片（最后手段）
    private func fetchViaWebView(url tweetUrl: String) async throws -> TweetInfo {
        guard let tweetId = extractTweetId(from: tweetUrl) else { throw TwitterError.invalidURL }
        guard let pageURL = URL(string: tweetUrl) else { throw TwitterError.invalidURL }
        
        let urls = try await MainActor.run {
            let fetcher = TweetPageFetcher()
            return try await fetcher.fetchImageURLs(from: pageURL)
        }
        
        guard !urls.isEmpty else { throw TwitterError.noImagesFound("webview: no images in DOM") }
        
        let images = urls.reduce(into: [ImageInfo]()) { r, url in
            if let u = URL(string: url) {
                r.append(ImageInfo(url: u, width: 0, height: 0))
            }
        }
        
        return TweetInfo(tweetId: tweetId, username: "unknown",
                        displayName: nil, tweetText: nil,
                        createdAt: Date(), images: images)
    }
    
    /// 通过 syndication API 获取推文（不需要登录）
    private func fetchViaSyndication(url tweetUrl: String) async throws -> TweetInfo {
        guard let tweetId = extractTweetId(from: tweetUrl) else { throw TwitterError.invalidURL }
        let apiURL = URL(string: "https://cdn.syndication.twimg.com/tweet-result?id=\(tweetId)")!
       var request = URLRequest(url: apiURL)
       request.timeoutInterval = 15
        await addCookies(to: &request)
       let (data, response) = try await session.data(for: request)
       guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TwitterError.fetchFailed
        }
        let mediaUrls = findValues(forKey: "media_url_https", in: json)
        guard !mediaUrls.isEmpty else { throw TwitterError.noImagesFound("syndication: no media_url_https") }
        let images = mediaUrls.reduce(into: [ImageInfo]()) { result, urlStr in
            let img = ImageInfo(url: origURL(from: urlStr), width: 0, height: 0)
            if !result.contains(where: { $0.url == img.url }) { result.append(img) }
        }
        let username = findValue(forKey: "screen_name", in: json) ?? "unknown"
        let displayName = findValue(forKey: "name", in: json)
        let tweetText = findTweetText(in: json)
        let dateStr = findValue(forKey: "created_at", in: json) ?? ""
        let date = parseTwitterDate(dateStr) ?? Date()
        return TweetInfo(tweetId: tweetId, username: username,
                        displayName: displayName, tweetText: tweetText,
                        createdAt: date, images: images)
    }
    
    /// 解析推文页面 HTML（后备）
    private func fetchViaPage(url tweetUrl: String) async throws -> TweetInfo {
        guard let tweetId = extractTweetId(from: tweetUrl) else {
             throw TwitterError.invalidURL
         }
         
         // 构造推文页面 URL
         let pageURL: URL
         if tweetUrl.contains("twitter.com") {
             pageURL = URL(string: tweetUrl)!
         } else if tweetUrl.contains("x.com") {
             pageURL = URL(string: tweetUrl)!
         } else {
             throw TwitterError.invalidURL
         }
         
         var request = URLRequest(url: pageURL)
         request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
         request.timeoutInterval = 30
         
         // 附加已保存的 Cookie（如果已登录）
         await addCookies(to: &request)
         
         let (data, response) = try await session.data(for: request)
         
         guard let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 else {
             throw TwitterError.fetchFailed
         }
         
         guard let html = String(data: data, encoding: .utf8) else {
             throw TwitterError.parseFailed
         }
         
         return try parseTweetPage(html: html, tweetId: tweetId, sourceUrl: pageURL.absoluteString)
     }
     
     // MARK: - 解析 HTML
     
    private func parseTweetPage(html: String, tweetId: String, sourceUrl: String) throws -> TweetInfo {
        let hasNextData = html.contains("__NEXT_DATA__")
        let hasMediaUrl = html.contains("media_url_https")
        let hasPbs = html.contains("pbs.twimg.com")
        
        // 方法1: 解析 __NEXT_DATA__ JSON
        if let nextDataJSON = extractJSON(from: html, scriptId: "__NEXT_DATA__"),
            let data = nextDataJSON.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
             
             // 递归搜索 media_url_https
             let mediaUrls = findValues(forKey: "media_url_https", in: json)
             
             if !mediaUrls.isEmpty {
                 // 同时获取宽高信息
                 let sizes = findMediaSizes(in: json)
                 let images = zip(mediaUrls, sizes).map { (urlStr, size) -> ImageInfo in
                     let cleanURL = origURL(from: urlStr)
                     return ImageInfo(url: cleanURL, width: size.0, height: size.1)
                 }.reduce(into: [ImageInfo]()) { result, img in
                     if !result.contains(where: { $0.url == img.url }) {
                         result.append(img)
                     }
                 }
                 
                 // 提取用户信息
                 let username = findValue(forKey: "screen_name", in: json) ?? "unknown"
                 let displayName = findValue(forKey: "name", in: json)
                 let tweetText = findTweetText(in: json)
                 let dateStr = findValue(forKey: "created_at", in: json) ?? ""
                 let date = parseTwitterDate(dateStr) ?? Date()
                 
                 return TweetInfo(
                     tweetId: tweetId, username: username,
                     displayName: displayName, tweetText: tweetText,
                     createdAt: date, images: images
                 )
             }
         }
        
        // 方法2: 直接从 HTML 中提取 pbs.twimg.com 图片 URL（兜底）
        let imgURLs = extractImageURLsFromHTML(html)
        if !imgURLs.isEmpty {
             let unique = Array(Set(imgURLs)).map { origURL(from: $0) }
             let images = unique.map { ImageInfo(url: $0, width: 0, height: 0) }
             return TweetInfo(tweetId: tweetId, username: "unknown",
                             displayName: nil, tweetText: nil,
                             createdAt: Date(), images: images)
         }
        
        let hasPbsMedia = html.contains("pbs.twimg.com/media/")
        throw TwitterError.noImagesFound(
            "nd=" + String(hasNextData) + " mu=" + String(hasMediaUrl) + " pb=" + String(hasPbs) + " pm=" + String(hasPbsMedia) + " sz=" + String(html.count)
        )
    }
    
    // MARK: - JSON 解析辅助
     
    private func extractJSON(from html: String, scriptId: String) -> String? {
        let pattern = #"<script id="\#(scriptId)"[^>]*type="application/json"[^>]*>([\s\S]*?)</script>"#
        guard let range = html.range(of: pattern, options: .regularExpression) else { return nil }
         let script = String(html[range])
         let start = script.firstIndex(of: ">") ?? script.startIndex
         let end = script.lastIndex(of: "<") ?? script.endIndex
         guard start < end else { return nil }
         let json = script[script.index(after: start)..<end]
         return String(json).trimmingCharacters(in: .whitespacesAndNewlines)
     }
     
     private func findValues(forKey key: String, in json: Any) -> [String] {
         var results: [String] = []
         if let dict = json as? [String: Any] {
             for (k, v) in dict {
                 if k == key, let str = v as? String {
                     results.append(str)
                 } else {
                     results.append(contentsOf: findValues(forKey: key, in: v))
                 }
             }
         } else if let array = json as? [Any] {
             for item in array {
                 results.append(contentsOf: findValues(forKey: key, in: item))
             }
         }
         return results
     }
     
     private func findValue(forKey key: String, in json: Any) -> String? {
         if let dict = json as? [String: Any] {
             for (k, v) in dict {
                 if k == key { return v as? String }
                 if let found = findValue(forKey: key, in: v) { return found }
             }
         } else if let array = json as? [Any] {
             for item in array {
                 if let found = findValue(forKey: key, in: item) { return found }
             }
         }
         return nil
     }
     
     private func findMediaSizes(in json: Any) -> [(Int, Int)] {
         var results: [(Int, Int)] = []
         if let dict = json as? [String: Any] {
             if let w = dict["w"] as? Int, let h = dict["h"] as? Int,
                dict.keys.contains("resize") {
                 results.append((w, h))
             }
             for (_, v) in dict {
                 results.append(contentsOf: findMediaSizes(in: v))
             }
         } else if let array = json as? [Any] {
             for item in array {
                 results.append(contentsOf: findMediaSizes(in: item))
             }
         }
         return results
     }
     
     private func findTweetText(in json: Any) -> String? {
         if let dict = json as? [String: Any] {
             if let text = dict["full_text"] as? String { return text }
             if let text = dict["text"] as? String { return text }
             for (_, v) in dict {
                 if let found = findTweetText(in: v) { return found }
             }
         } else if let array = json as? [Any] {
             for item in array {
                 if let found = findTweetText(in: item) { return found }
             }
         }
         return nil
     }
     
     // MARK: - HTML 图片提取（兜底）
     
     private func extractImageURLsFromHTML(_ html: String) -> [String] {
         let pattern = #"https://pbs\.twimg\.com/media/[^"'\s?]+"#
         let regex = try? NSRegularExpression(pattern: pattern)
         let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
         let matches = regex?.matches(in: html, range: nsRange) ?? []
         return matches.compactMap {
             guard let range = Range($0.range, in: html) else { return nil }
             return String(html[range])
         }
     }
     
     // MARK: - URL 处理
     
     private func origURL(from urlStr: String) -> URL {
         // 去掉 query 参数，加上 ?name=orig
         if let base = urlStr.components(separatedBy: "?").first {
             return URL(string: base + "?name=orig") ?? URL(string: urlStr)!
         }
         return URL(string: urlStr)!
     }
     
     private func parseTwitterDate(_ str: String) -> Date? {
         let fmt = DateFormatter()
         fmt.locale = Locale(identifier: "en_US_POSIX")
         fmt.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
         return fmt.date(from: str)
     }
     
     // MARK: - Cookie 管理
     
     private func addCookies(to request: inout URLRequest) async {
         guard let cookies = await AuthService.shared.cookiesForX else { return }
         let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
         request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
     }
 }
 
 // MARK: - Errors
 
enum TwitterError: LocalizedError {
    case invalidURL, fetchFailed, parseFailed, noImagesFound(String), notLoggedIn
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的推文链接"
        case .fetchFailed: return "获取推文失败"
        case .parseFailed: return "解析推文失败"
        case .noImagesFound(let detail): return "没有找到图片\n[诊断] \(detail)"
        case .notLoggedIn: return "请先登录 X 账号"
        }
    }
}
