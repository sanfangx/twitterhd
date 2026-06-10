 import SwiftUI
 import UniformTypeIdentifiers
 
 struct DownloadView: View {
     @State private var tweetURL = ""
     @State private var isDownloading = false
     @State private var downloadedImages: [(url: URL, image: UIImage)] = []
     @State private var tweetInfo: TweetInfo?
     @State private var errorMessage: String?
     @State private var showError = false
     @State private var showPreview = false
     @State private var previewIndex = 0
     @State private var progressText = ""
     
     @AppStorage("autoSave") private var autoSave = true
     @StateObject private var authService = AuthService.shared
     
     var body: some View {
         NavigationStack {
             VStack(spacing: 0) {
                 if !authService.isLoggedIn {
                     notLoggedInView
                 } else {
                     contentView
                 }
             }
             .navigationTitle("下载")
         }
     }
     
     // MARK: - 未登录
     
     private var notLoggedInView: some View {
         VStack(spacing: 24) {
             Image(systemName: "lock.shield")
                 .font(.system(size: 60))
                 .foregroundColor(.secondary)
             Text("需要登录 X 账号")
                 .font(.title3)
                 .fontWeight(.semibold)
             Text("部分推文的图片需要登录后才能查看\n请先登录你的 X 账号")
                 .multilineTextAlignment(.center)
                 .foregroundColor(.secondary)
             NavigationLink("登录 X") {
                 LoginView()
             }
             .buttonStyle(.borderedProminent)
         }
         .padding()
     }
     
     // MARK: - 主内容
     
     private var contentView: some View {
         ScrollView {
             VStack(spacing: 16) {
                 // 输入区域
                 VStack(spacing: 10) {
                     HStack {
                         Image(systemName: "link")
                             .foregroundColor(.secondary)
                         TextField("粘贴推文链接...", text: $tweetURL)
                             .textFieldStyle(.plain)
                             .autocapitalization(.none)
                             .disableAutocorrection(true)
                         if !tweetURL.isEmpty {
                             Button { tweetURL = "" } label: {
                                 Image(systemName: "xmark.circle.fill")
                                     .foregroundColor(.secondary)
                             }
                         }
                     }
                     .padding(12)
                     .background(Color(.systemGray6))
                     .cornerRadius(10)
                     
                     Button(action: startDownload) {
                         if isDownloading {
                             ProgressView()
                                 .progressViewStyle(.circular)
                                 .tint(.white)
                         } else {
                             Label("下载图片", systemImage: "arrow.down.circle")
                         }
                     }
                     .frame(maxWidth: .infinity)
                     .frame(height: 44)
                     .background(tweetURL.isEmpty || isDownloading ? Color.gray : Color.blue)
                     .foregroundColor(.white)
                     .cornerRadius(10)
                     .disabled(tweetURL.isEmpty || isDownloading)
                 }
                 .padding(.horizontal)
                 .padding(.top, 8)
                 
                 // 进度文本
                 if !progressText.isEmpty {
                     Text(progressText)
                         .font(.subheadline)
                         .foregroundColor(.secondary)
                 }
                 
                 // 图片网格
                 if !downloadedImages.isEmpty {
                     LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                         ForEach(Array(downloadedImages.enumerated()), id: \.offset) { index, item in
                             Button {
                                 previewIndex = index
                                 showPreview = true
                             } label: {
                                 Image(uiImage: item.image)
                                     .resizable()
                                     .scaledToFill()
                                     .frame(height: 150)
                                     .clipShape(RoundedRectangle(cornerRadius: 8))
                             }
                         }
                     }
                     .padding(.horizontal)
                 }
                 
                 // 快捷粘贴按钮
                 if tweetURL.isEmpty && !isDownloading {
                     Button {
                         if let str = UIPasteboard.general.string {
                             tweetURL = str
                         }
                     } label: {
                         Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                     }
                     .buttonStyle(.bordered)
                 }
                 
                 Spacer()
             }
         }
         .fullScreenCover(isPresented: $showPreview) {
             ImagePreviewView(
                 images: downloadedImages.map { $0.image },
                 currentIndex: previewIndex,
                 autoSave: autoSave
             )
         }
         .alert("错误", isPresented: $showError) {
             Button("确定") {}
         } message: {
             Text(errorMessage ?? "未知错误")
         }
     }
     
     // MARK: - 下载逻辑
     
     private func startDownload() {
         guard !tweetURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
         
         let url = tweetURL.trimmingCharacters(in: .whitespacesAndNewlines)
         isDownloading = true
         progressText = "正在获取推文..."
         downloadedImages = []
         
         Task {
             do {
                 let info = try await TwitterService.shared.fetchTweet(url: url)
                 tweetInfo = info
                 
                 guard !info.images.isEmpty else {
                     throw TwitterError.noImagesFound
                 }
                 
                 let urls = info.images.map { $0.url }
                 progressText = "找到 \(urls.count) 张图片，开始下载..."
                 
                // 下载所有图片
                let stream = await ImageDownloadService.shared.downloadImages(urls, autoSave: autoSave)
                for await event in stream {
                    switch event {
                    case .started(let total):
                        await MainActor.run { progressText = "共 \(total) 张图片" }
                    case .progress(let current, let total):
                        await MainActor.run { progressText = "下载中 \(current)/\(total)" }
                    case .completed(let count):
                        await MainActor.run {
                            progressText = "✅ 已完成 \(count) 张"
                            if autoSave { progressText += "（已保存到相册）" }
                        }
                    case .imageReady(let url, let image):
                        await ImageCache.shared.set(image, for: url)
                        await MainActor.run {
                            downloadedImages.append((url, image))
                        }
                    case .error(let error):
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
                
                // 保存到 Core Data
                if !downloadedImages.isEmpty {
                    let imgData = downloadedImages.map {
                        (url: $0.url.absoluteString, w: Int32($0.image.size.width), h: Int32($0.image.size.height))
                    }
                    CoreDataManager.shared.saveTweet(
                        tweetId: info.tweetId,
                        tweetUrl: url,
                        username: info.username,
                        displayName: info.displayName,
                        tweetText: info.tweetText,
                        createdAt: info.createdAt,
                        images: imgData
                    )
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run { isDownloading = false }
        }
    }
 }
