import SwiftUI
import WebKit
 
struct LoginView: View {
    @StateObject private var manager = WebViewManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if manager.isLoggedIn {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64)).foregroundColor(.green)
                        Text("登录成功").font(.title2).fontWeight(.bold)
                        Text("可以开始下载了").foregroundColor(.secondary)
                        Button("开始使用") { dismiss() }
                            .buttonStyle(.borderedProminent).padding(.top, 10)
                    }
                } else {
                    WebViewWrapper(webView: manager.webView)
                        .onAppear {
                            manager.webView.load(URLRequest(url: URL(string: "https://x.com/login")!))
                        }
                }
            }
            .navigationTitle("登录 X")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
 
struct WebViewWrapper: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_: WKWebView, context: Context) {}
}
