import SwiftUI

/// 应用主容器界面，提供底部导航切换主下载栏、解析历史与设置页面，同时展示用户挑选的相册自定义背景
public struct ContentView: View {
    @State private var selectedTab: Int = 0
    @StateObject private var downloaderVM = DownloaderViewModel()
    @ObservedObject private var bgManager = AppBackgroundManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 用户通过相册选择的自定义背景图
            if let bgImage = bgManager.customBackgroundImage {
                Image(uiImage: bgImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color(.systemBackground).opacity(0.85))
            }
            
            TabView(selection: $selectedTab) {
                MainDownloaderView(viewModel: downloaderVM)
                    .tabItem {
                        Label("原图抓取", systemImage: "arrow.down.to.line.circle.fill")
                    }
                    .tag(0)
                
                HistoryView(selectedTab: $selectedTab, downloaderViewModel: downloaderVM)
                    .tabItem {
                        Label("解析历史", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("设置登录", systemImage: "gearshape.fill")
                    }
                    .tag(2)
            }
            .tint(.blue)
        }
    }
}
