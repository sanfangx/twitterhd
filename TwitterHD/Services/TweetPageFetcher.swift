import UIKit
import WebKit
 
@MainActor
class TweetPageFetcher: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var loadContinuation: CheckedContinuation<[String], Error>?
    
    func fetchImageURLs(from url: URL, timeout: TimeInterval = 15) async throws -> [String] {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let pref = WKWebpagePreferences()
        pref.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pref
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let wv = WKWebView(frame: .init(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.isHidden = true
        wv.navigationDelegate = self
        self.webView = wv
        
        // Set saved cookies before loading
        if let cookies = await AuthService.shared.cookiesForX {
            let store = wv.configuration.websiteDataStore.httpCookieStore
            for cookie in cookies {
                await store.setCookie(cookie)
            }
        }
        
        wv.load(URLRequest(url: url, timeoutInterval: timeout))
        
        return try await withCheckedThrowingContinuation { continuation in
            self.loadContinuation = continuation
        }
    }
    
    nonisolated func webView(_ wv: WKWebView, didFinish nav: WKNavigation!) {
        Task { @MainActor in await self.extractImages(from: wv) }
    }
    
    nonisolated func webView(_ wv: WKWebView, didFail nav: WKNavigation!, withError e: Error) {
        Task { @MainActor in
            self.loadContinuation?.resume(throwing: e)
            self.cleanup()
        }
    }
    
    nonisolated func webView(_ wv: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError e: Error) {
        let ns = e as NSError
        if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return }
        Task { @MainActor in
            self.loadContinuation?.resume(throwing: e)
            self.cleanup()
        }
    }
    
    private func extractImages(from wv: WKWebView) async {
        let js = """
        JSON.stringify(
          Array.from(document.querySelectorAll('[data-testid="tweetPhoto"] img, [data-testid="tweetPhoto"] video[poster]'))
            .map(el => el.tagName === 'IMG' ? el.src : el.poster)
            .filter(s => s && s.includes('pbs.twimg.com'))
            .map(s => s.split('?')[0] + '?name=orig')
        )
        """
        
        do {
            if let result = try await wv.evaluateJavaScript(js) as? String,
               let data = result.data(using: .utf8),
               let urls = try JSONSerialization.jsonObject(with: data) as? [String] {
                self.loadContinuation?.resume(returning: urls)
            } else {
                self.loadContinuation?.resume(returning: [])
            }
        } catch {
            self.loadContinuation?.resume(throwing: error)
        }
        cleanup()
    }
    
    private func cleanup() {
        webView?.stopLoading()
        webView = nil
        loadContinuation = nil
    }
}
