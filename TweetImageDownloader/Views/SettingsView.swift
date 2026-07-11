import SwiftUI
import WebKit

/// 设置界面：支持打开后台网页进行 Twitter/X 登录与会话管理以及介绍快捷指令使用方法
public struct SettingsView: View {
    @State private var showLoginModal: Bool = false
    @State private var cacheClearedAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showLoginModal = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.title2)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("登录 Twitter / X 后台网页")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("在可视化页面中登录账号，解决私密推文及防机器人拦截")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("账号与鉴权")
                } footer: {
                    Text("登录状态保存在底层 WKWebView Cookie 中，App 重新启动依然有效。")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "command.square.fill")
                                .foregroundColor(.orange)
                            Text("苹果快捷指令 (App Intents)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        Text("您可以在 iOS「快捷指令」应用中搜索“下载推文原图”或“解析推特链接”，结合系统 Share Sheet 实现从 Safari / X 客户端一键传递推文链接并全自动存入相册。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("自动化指南")
                }
                
                Section {
                    Button(role: .destructive) {
                        clearWebViewCache()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("清除网页缓存与登录会话")
                        }
                    }
                } header: {
                    Text("数据与维护")
                }
            }
            .navigationTitle("设置 & 账号")
            .sheet(isPresented: $showLoginModal) {
                TwitterLoginSheetView()
            }
            .alert("缓存已清理", isPresented: $cacheClearedAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("后台 WKWebView 的 Cookie 与页面缓存已清空，您随时可以重新登录。")
            }
        }
    }
    
    private func clearWebViewCache() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: Date(timeIntervalSince1970: 0)) {
            DispatchQueue.main.async {
                self.cacheClearedAlert = true
            }
        }
    }
}
