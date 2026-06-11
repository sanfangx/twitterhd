import SwiftUI
 
struct ContentView: View {
    @State private var backgroundImage: UIImage? = nil
    
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
            if let img = backgroundImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
        }
        .onAppear { backgroundImage = BackgroundManager.shared.image }
        .onReceive(BackgroundManager.shared.$image) { img in
            withAnimation(.easeInOut(duration: 0.3)) { backgroundImage = img }
        }
    }
}
