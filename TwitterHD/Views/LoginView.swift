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
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("登录成功").font(.title2).fontWeight(.bold)
            Text("Cookies 已保存，可以开始下载了").foregroundColor(.secondary)
            Button("开始使用") { dismiss() }
                .buttonStyle(.borderedProminent).padding(.top, 10)
        }
    }
    
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50)).foregroundColor(.orange)
            Text("加载失败").font(.title2)
            Text(msg).font(.body).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button("重试") { viewModel.errorMessage = nil }.buttonStyle(.bordered)
            Button("取消") { dismiss() }.buttonStyle(.bordered)
        }.padding()
    }
}
 
// MARK: - WKWebView 包装器
 
struct WebViewWrapper: UIViewRepresentable {
    @ObservedObject var viewModel: LoginViewModel
    
    func makeUIView(context: Context) -> WKWebView {
        viewModel.makeWebView()
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
 
// MARK: - LoginViewModel
 
class LoginViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var isLoading = false
    @Published var didSucceed = false
    @Published var errorMessage: String?
    
    private var webView: WKWebView?
    
    func makeWebView() -> WKWebView {
        if let existing = webView { return existing }
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView = wv
        wv.load(URLRequest(url: URL(string: "https://x.com/login")!))
        return wv
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        checkCookies(webView)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false; checkCookies(webView)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false; errorMessage = error.localizedDescription
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false; errorMessage = error.localizedDescription
    }
    
    private func checkCookies(_ webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            let hasAuth = cookies.contains { $0.name == "auth_token" && !$0.value.isEmpty }
            let hasCt0 = cookies.contains { $0.name == "ct0" && !$0.value.isEmpty }
            if hasAuth && hasCt0 {
                Task { @MainActor in
                    await AuthService.shared.saveCookies(from: webView)
                    self?.didSucceed = true
                }
            }
        }
    }
}
