import SwiftUI
import WebKit

/// 包装底层常驻 WKWebView，使其可在“设置”页面中弹出以展示 Twitter/X 网页登录界面
@MainActor
public struct LoginWebViewModal: UIViewRepresentable {
    public let webView: WKWebView
    public let initialURL: URL
    
    public init(webView: WKWebView = TwitterWebViewService.shared.webView, initialURL: URL = URL(string: "https://x.com/login")!) {
        self.webView = webView
        self.initialURL = initialURL
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        // 如果当前网页不在 Twitter/X 登录页或首页，自动跳转到登录界面
        if let currentURL = webView.url, currentURL.host?.contains("x.com") == true || currentURL.host?.contains("twitter.com") == true {
            // 已经在推特内部页面即可继续操作
        } else {
            webView.load(URLRequest(url: initialURL))
        }
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// 登录页弹窗封装视图
public struct TwitterLoginSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            LoginWebViewModal()
                .navigationTitle("登录 Twitter / X")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("刷新") {
                            TwitterWebViewService.shared.webView.reload()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            dismiss()
                        }
                        .bold()
                    }
                }
        }
    }
}
