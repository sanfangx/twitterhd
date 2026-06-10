 import SwiftUI
 
 @main
 struct TwitterHDApp: App {
     
     init() {
         _ = CoreDataManager.shared
     }
     
     var body: some Scene {
         WindowGroup {
             ContentView()
         }
     }
 }
