 import SwiftUI
 
 struct SettingsView: View {
    @ObservedObject private var bg = BackgroundManager.shared
    @State private var showImagePicker = false
    @State private var pickedImageData: Data?
     @AppStorage("autoSave") private var autoSave = true
     @AppStorage("imageQuality") private var imageQuality = "orig"
     @StateObject private var authService = AuthService.shared
     @State private var showLogoutAlert = false
     @State private var showClearConfirm = false
     
     private let qualities = [
         ("orig", "原始画质 (orig)"),
         ("large", "大图 (large)"),
         ("medium", "中等 (medium)"),
     ]
     
     var body: some View {
         NavigationStack {
             List {
                 // MARK: 下载设置
                 Section("下载设置") {
                     Toggle(isOn: $autoSave) {
                         VStack(alignment: .leading, spacing: 2) {
                             Text("自动保存到相册")
                             Text("开启后下载完成自动保存，关闭后可手动选择")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                         }
                     }
                     
                     Picker("图片质量", selection: $imageQuality) {
                         ForEach(qualities, id: \.0) { quality, label in
                             Text(label).tag(quality)
                         }
                     }
                 }
                 
                 // MARK: 账号
                 Section("账号") {
                     if authService.isLoggedIn {
                         HStack {
                             Image(systemName: "person.circle.fill")
                                 .foregroundColor(.blue)
                             Text("已登录 X")
                             Spacer()
                             Button("退出登录", role: .destructive) {
                                 showLogoutAlert = true
                             }
                         }
                     } else {
                         NavigationLink {
                             LoginView()
                         } label: {
                             Label("登录 X", systemImage: "person.circle")
                         }
                     }
                 }
                 
                 // MARK: 数据
                 Section("数据") {
                     Button(role: .destructive) {
                         showClearConfirm = true
                     } label: {
                         Label("清除下载历史", systemImage: "trash")
                     }
                 }
                 
                // MARK: 背景
                Section("背景图片") {
                    if let img = bg.image {
                        Image(uiImage: img)
                            .resizable().scaledToFill().frame(height: 120).clipped().cornerRadius(8)
                    }
                    Button("选择图片") { showImagePicker = true }
                    if bg.hasImage {
                        Button("清除背景", role: .destructive) { bg.clear() }
                    }
                }
                 // MARK: 关于
                 Section {
                     HStack {
                         Text("版本")
                         Spacer()
                         Text("0.1.0")
                             .foregroundColor(.secondary)
                     }
                     
                     Link(destination: URL(string: "https://github.com/sanfangx/twitterhd")!) {
                         HStack {
                             Text("GitHub")
                             Spacer()
                             Image(systemName: "arrow.up.right")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                         }
                     }
                 } header: {
                     Text("关于")
                 }
             }
             .navigationTitle("设置")
             .alert("退出登录", isPresented: $showLogoutAlert) {
                 Button("取消", role: .cancel) {}
                 Button("退出", role: .destructive) {
                     authService.logout()
                 }
             } message: {
                 Text("退出后需要重新登录才能下载需要认证的图片")
             }
             .alert("清除历史", isPresented: $showClearConfirm) {
                 Button("取消", role: .cancel) {}
                 Button("清除", role: .destructive) {
                     clearHistory()
                 }
             } message: {
                 Text("将删除所有下载记录，此操作不可撤销")
             }
         }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(imageData: $pickedImageData)
        }
        .onChange(of: pickedImageData) { data in
            if let d = data, let img = UIImage(data: d) { BackgroundManager.shared.save(img) }
        }
     }
     
     private func clearHistory() {
         let records = CoreDataManager.shared.fetchHistory()
         records.forEach { CoreDataManager.shared.deleteTweet($0) }
     }
 }