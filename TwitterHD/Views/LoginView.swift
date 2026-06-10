import SwiftUI
import WebKit
 
struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.didSucceed {
                    successView
                } else if let err = viewModel.errorMessage {
                    errorView(err)
                } else {
                    WebViewWrapper(viewModel: viewModel)
                }
            }
            .navigationTitle("登录 X")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !viewModel.didSucceed {
                        Button("取消") { dismiss() }
                    }
                }
            }
        }
    }
    
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(.green)
            Text("登录成功").font(.title2).fontWeight(.bold)
            Text("Cookies 已保存").foregroundColor(.secondary)
            Button("开始使用") { dismiss() }.buttonStyle(.borderedProminent).padding(.top, 10)
        }
    }
    
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 50)).foregroundColor(.orange)
            Text("加载失败").font(.title2)
            Text(msg).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Button("重试") { viewModel.errorMessage = nil }.buttonStyle(.bordered)
            Button("取消") { dismiss() }.buttonStyle(.bordered)
        }.padding()
    }
}
 
struct WebViewWrapper: UIViewRepresentable {
    @ObservedObject var viewModel: LoginViewModel
    func makeUIView(context: Context) -> WKWebView { viewModel.makeWebView() }
    func updateUIView(_: WKWebView, context: Context) {}
}
 
@MainActor
class LoginViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var isLoading = false
    @Published var didSucceed = false
    @Published var errorMessage: String?
    private var webView: WKWebView?
    
    func makeWebView() -> WKWebView {
        if let existing = webView { return existing }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let pref = WKWebpagePreferences()
        pref.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pref
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView = wv
        wv.load(URLRequest(url: URL(string: "https://x.com/login")!))
        return wv
    }
    
    nonisolated func webView(_ wv: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, let scheme = url.scheme?.lowercased() {
            if !["http", "https", "about", "data", "blob", "file"].contains(scheme) {
                Task { @MainActor in UIApplication.shared.open(url, options: [:], completionHandler: nil) }
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    nonisolated func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        Task { @MainActor in self.isLoading = true }
    }
    nonisolated func webView(_ wv: WKWebView, didCommit _: WKNavigation!) { checkCookies(wv) }
    nonisolated func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
        Task { @MainActor in self.isLoading = false }; checkCookies(wv)
    }
    nonisolated func webView(_: WKWebView, didFail _: WKNavigation!, withError e: Error) {
        Task { @MainActor in self.isLoading = false; self.errorMessage = e.localizedDescription }
    }
    nonisolated func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError e: Error) {
        Task { @MainActor in self.isLoading = false; self.errorMessage = e.localizedDescription }
    }
    
    private nonisolated func checkCookies(_ wv: WKWebView) {
        wv.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            let hasAuth = cookies.contains { $0.name == "auth_token" && !$0.value.isEmpty }
            let hasCt0 = cookies.contains { $0.name == "ct0" && !$0.value.isEmpty }
            if hasAuth && hasCt0 {
                Task { @MainActor in
                    await AuthService.shared.saveCookies(from: wv)
                    self?.didSucceed = true
                }
            }
        }
    }
}
