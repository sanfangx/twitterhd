import UIKit
import WebKit
 
@MainActor
class WebViewManager: NSObject, ObservableObject {
    static let shared = WebViewManager()
    
    @Published var isLoggedIn = false
    
    let webView: WKWebView
    private var pageContinuation: CheckedContinuation<[String], Error>?
    
    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let pref = WKWebpagePreferences()
        pref.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pref
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.webView = wv
        
        super.init()
        wv.navigationDelegate = self
        checkLoginState()
    }
    
    private func checkLoginState() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            let ok = cookies.contains { $0.name == "auth_token" && !$0.value.isEmpty }
                && cookies.contains { $0.name == "ct0" && !$0.value.isEmpty }
            Task { @MainActor in self?.isLoggedIn = ok }
        }
    }
    
    func extractImages(from tweetURL: URL) async throws -> [String] {
        pageContinuation = nil
        webView.load(URLRequest(url: tweetURL))
        return try await withCheckedThrowingContinuation { [weak self] c in
            self?.pageContinuation = c
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                self?.pageContinuation?.resume(returning: [])
                self?.pageContinuation = nil
            }
        }
    }
   
    private func handlePageLoaded() {
        guard let cont = pageContinuation else { return }
        let js = """
        JSON.stringify(
          Array.from(document.querySelectorAll('[data-testid="tweetPhoto"] img'))
            .map(i => i.src)
            .filter(s => s && s.includes('pbs.twimg.com'))
            .map(s => s.split('?')[0] + '?name=orig')
        )
        """
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self, let cont = self.pageContinuation else { return }
            if let json = result as? String,
                      let data = json.data(using: .utf8),
                      let urls = try? JSONSerialization.jsonObject(with: data) as? [String],
                      !urls.isEmpty {
                cont.resume(returning: urls)
                self.pageContinuation = nil
            }
            // 没找到图片不 resolve，等下一次 didFinish 或超时
        }
    }
}
 
extension WebViewManager: WKNavigationDelegate {
    nonisolated func webView(_ wv: WKWebView, didFinish nav: WKNavigation!) {
        Task { @MainActor in
            self.checkLoginState()
            await AuthService.shared.saveCookies(from: wv)
            self.handlePageLoaded()
        }
    }
    
    nonisolated func webView(_ wv: WKWebView, didFail nav: WKNavigation!, withError e: Error) {
        Task { @MainActor in
            self.pageContinuation?.resume(throwing: e)
            self.pageContinuation = nil
        }
    }
    
    nonisolated func webView(_ wv: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError e: Error) {
        let ns = e as NSError
        if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return }
        Task { @MainActor in
            self.pageContinuation?.resume(throwing: e)
            self.pageContinuation = nil
        }
    }
}
