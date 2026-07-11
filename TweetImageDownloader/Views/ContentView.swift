import SwiftUI

/// 应用主容器界面，提供底部导航切换主下载栏与设置页面
public struct ContentView: View {
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            MainDownloaderView()
                .tabItem {
                    Label("原图抓取", systemImage: "arrow.down.to.line.circle.fill")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("设置登录", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .tint(.blue)
    }
}
