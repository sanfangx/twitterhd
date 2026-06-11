import SwiftUI
 
struct ContentView: View {
    @ObservedObject private var bg = BackgroundManager.shared
    
    var body: some View {
        TabView {
            DownloadView()
                .tabItem { Label("下载", systemImage: "arrow.down.circle") }
            HistoryView()
                .tabItem { Label("历史", systemImage: "clock") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .background {
            if let img = bg.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
        }
    }
}
