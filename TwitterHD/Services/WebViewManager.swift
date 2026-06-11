import UIKit
import WebKit
 
@MainActor
class WebViewManager: NSObject, ObservableObject {
    static let shared = WebViewManager()
    
    @Published var isLoggedIn = false
    
    let webView: WKWebView
    private var pageContinuation: CheckedContinuation<[String], Error>?
    
    private override init() {
        let js = """
        function scan() {
            let res = [];
            document.querySelectorAll('img[src*="pbs.twimg.com/media/"]').forEach(img => {
                try {
                    let u = new URL(img.src);
                    let f = new URLSearchParams(u.search).get('format') || 'jpg';
                    res.push(u.origin + u.pathname + "?format=" + f + "&name=orig");
                } catch(e) {}
            });
            if (res.length > 0)
                window.webkit.messageHandlers.scanner.postMessage(Array.from(new Set(res)));
        }
        setInterval(() => {
            document.querySelectorAll('div[role="button"]').forEach(btn => {
                if(btn.innerText.includes("\\u663E\\u793A") || btn.innerText.includes("View")) btn.click();
            });
            scan();
        }, 1500);
        """
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        let cc = WKUserContentController()
        cc.addUserScript(userScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = cc
        config.websiteDataStore = WKWebsiteDataStore.default()
        let pref = WKWebpagePreferences()
        pref.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pref
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.applicationNameForUserAgent = "Version/17.4 Mobile/15E148 Safari/604.1"
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.webView = wv
        
        super.init()
        wv.navigationDelegate = self
        cc.add(self, name: "scanner")
        
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
}
 
extension WebViewManager: WKNavigationDelegate {
    nonisolated func webView(_ wv: WKWebView, didFinish nav: WKNavigation!) {
        Task { @MainActor in
            self.checkLoginState()
            await AuthService.shared.saveCookies(from: wv)
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
 
extension WebViewManager: WKScriptMessageHandler {
    nonisolated func userContentController(_ c: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard msg.name == "scanner" else { return }
        Task { @MainActor in
            guard let urls = msg.body as? [String], !urls.isEmpty else { return }
            self.pageContinuation?.resume(returning: urls)
            self.pageContinuation = nil
        }
    }
}
