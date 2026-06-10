 import SwiftUI
 import WebKit
 
 struct LoginView: View {
     @StateObject private var viewModel = LoginViewModel()
     @Environment(\.dismiss) private var dismiss
     
     var body: some View {
         NavigationStack {
             VStack(spacing: 0) {
                 if viewModel.didSucceed {
                     VStack(spacing: 20) {
                         Image(systemName: "checkmark.circle.fill")
                             .font(.system(size: 64))
                             .foregroundColor(.green)
                         Text("登录成功")
                             .font(.title2)
                             .fontWeight(.bold)
                         Text("Cookies 已保存，可以开始下载了")
                             .foregroundColor(.secondary)
                         Button("开始使用") {
                             dismiss()
                         }
                         .buttonStyle(.borderedProminent)
                         .padding(.top, 10)
                     }
                 } else {
                     // WKWebView 用于登录
                     WebViewWrapper(webView: viewModel.createWebView())
                         .overlay(alignment: .top) {
                             if viewModel.isLoading {
                                 ProgressView()
                                     .padding()
                             }
                         }
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
 }
 
 // MARK: - WKWebView 包装器
 
 struct WebViewWrapper: UIViewRepresentable {
     let webView: WKWebView
     
     func makeUIView(context: Context) -> WKWebView { webView }
     func updateUIView(_ uiView: WKWebView, context: Context) {}
 }
