 import SwiftUI
 
 struct ContentView: View {
     var body: some View {
         TabView {
             DownloadView()
                 .tabItem {
                     Label("下载", systemImage: "arrow.down.circle")
                 }
             
             HistoryView()
                 .tabItem {
                     Label("历史", systemImage: "clock")
                 }
             
             SettingsView()
                 .tabItem {
                     Label("设置", systemImage: "gearshape")
                 }
         }
     }
 }
