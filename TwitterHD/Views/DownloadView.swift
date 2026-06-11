import SwiftUI
import UniformTypeIdentifiers
 
struct DownloadView: View {
    @State private var tweetURL = ""
    @State private var isFetching = false
    @State private var isDownloading = false
    @State private var imageItems: [(small: URL, orig: URL)] = []
    @State private var selectedIndices = Set<Int>()
    @State private var tweetInfo: TweetInfo?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showPreview = false
    @State private var previewIndex = 0
    @State private var progressText = ""
    @State private var downloadProgress: (current: Int, total: Int)? = nil
    
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
    
    private var notLoggedInView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield").font(.system(size: 60)).foregroundColor(.secondary)
            Text("需要登录 X 账号").font(.title3).fontWeight(.semibold)
            Text("部分推文的图片需要登录后才能查看\n请先登录你的 X 账号").multilineTextAlignment(.center).foregroundColor(.secondary)
            NavigationLink("登录 X") { LoginView() }.buttonStyle(.borderedProminent)
        }.padding()
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // 输入区域
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "link").foregroundColor(.secondary)
                    TextField("粘贴推文链接...", text: $tweetURL)
                        .textFieldStyle(.plain).autocapitalization(.none).disableAutocorrection(true)
                    // 粘贴按钮
                    Button {
                        if let str = UIPasteboard.general.string { tweetURL = str }
                    } label: {
                        Image(systemName: "doc.on.clipboard").foregroundColor(.blue)
                    }
                    .disabled(tweetURL.isEmpty == false)
                    if !tweetURL.isEmpty {
                        Button { tweetURL = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12).background(Color(.systemGray6)).cornerRadius(10)
                
                HStack(spacing: 10) {
                    Button(action: fetchTweet) {
                        if isFetching {
                            ProgressView().progressViewStyle(.circular).tint(.white)
                        } else {
                            Label("获取图片", systemImage: "photo.on.rectangle")
                        }
                    }
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(tweetURL.isEmpty || isFetching || isDownloading ? Color.gray : Color.blue)
                    .foregroundColor(.white).cornerRadius(10)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .disabled(tweetURL.isEmpty || isFetching || isDownloading)
                    
                    if !imageItems.isEmpty {
                        Button(action: downloadSelected) {
                            if isDownloading {
                                ProgressView().progressViewStyle(.circular).tint(.white)
                            } else {
                                Label("下载选中 (\(selectedIndices.count))", systemImage: "arrow.down.circle")
                            }
                        }
                        .frame(height: 44).padding(.horizontal, 16)
                        .background(selectedIndices.isEmpty || isDownloading ? Color.gray : Color.green)
                        .foregroundColor(.white).cornerRadius(10)
                        .disabled(selectedIndices.isEmpty || isDownloading)
                    }
                }
            }
            .padding(.horizontal).padding(.top, 8)
            
            // 进度
            if !progressText.isEmpty {
                Text(progressText).font(.subheadline).foregroundColor(.secondary).padding(.top, 4)
            }
            
            // 图片网格
            if !imageItems.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(Array(imageItems.enumerated()), id: \.offset) { index, item in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: item.small) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFill()
                                    } else if phase.error != nil {
                                        Color.gray.overlay(Image(systemName: "photo"))
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedIndices.contains(index) ? Color.blue : Color.clear, lineWidth: 3))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedIndices.contains(index) {
                                        selectedIndices.remove(index)
                                    } else {
                                        selectedIndices.insert(index)
                                    }
                                }
                                
                                // 选择指示器
                                Image(systemName: selectedIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(selectedIndices.contains(index) ? .blue : .white)
                                    .padding(4)
                                    .shadow(radius: 1)
                            }
                        }
                    }
                    .padding()
                }
                
                // 全选/取消
                HStack {
                    Button(selectedIndices.count == imageItems.count ? "取消全选" : "全选") {
                        if selectedIndices.count == imageItems.count {
                            selectedIndices.removeAll()
                        } else {
                            selectedIndices = Set(0..<imageItems.count)
                        }
                    }
                    .font(.caption).foregroundColor(.blue)
                    Spacer()
                    Text("共 \(imageItems.count) 张图片").font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal).padding(.bottom, 8)
            }
            
            // 快捷粘贴
            if tweetURL.isEmpty && !isFetching && imageItems.isEmpty {
                Button {
                    if let str = UIPasteboard.general.string { tweetURL = str }
                } label: {
                    Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                }.buttonStyle(.bordered).padding()
            }
            Spacer()
        }
        .alert("错误", isPresented: $showError) {
            Button("确定") {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }
    
    // MARK: - 获取推文
    
    private func fetchTweet() {
        let url = tweetURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        
        isFetching = true
        progressText = "正在获取推文..."
        imageItems = []
        selectedIndices.removeAll()
        
        Task {
            defer { Task { @MainActor in isFetching = false } }
            do {
                let info = try await TwitterService.shared.fetchTweet(url: url)
                let items = info.images.map { img -> (small: URL, orig: URL) in
                    let u = img.url.absoluteString
                    let s: String, o: String
                    if u.contains("name=orig") {
                        s = u.replacingOccurrences(of: "name=orig", with: "name=small")
                        o = u
                    } else if u.contains("name=small") {
                        s = u
                        o = u.replacingOccurrences(of: "name=small", with: "name=orig")
                    } else {
                        s = u + "&name=small"
                        o = u + "&name=orig"
                    }
                    return (small: URL(string: s) ?? img.url, orig: URL(string: o) ?? img.url)
                }
                await MainActor.run {
                    imageItems = items
                    selectedIndices = []
                    progressText = "找到 \(items.count) 张图片，请选择后下载"
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    progressText = ""
                }
            }
        }
    }
    
    // MARK: - 下载选中
    
    private func downloadSelected() {
        guard !selectedIndices.isEmpty else { return }
        let selected = selectedIndices.sorted().compactMap { imageItems[safe: $0]?.orig }
        guard !selected.isEmpty else { return }
        
        isDownloading = true
        progressText = "下载中 0/\(selected.count)"
        var downloaded: [(URL, UIImage)] = []
        
        Task {
            let stream = await ImageDownloadService.shared.downloadImages(selected, autoSave: autoSave)
            for await event in stream {
                switch event {
                case .started(let total):
                    await MainActor.run { progressText = "共 \(total) 张" }
                case .progress(let cur, let total):
                    await MainActor.run { progressText = "下载中 \(cur)/\(total)" }
                case .completed(let count):
                    await MainActor.run {
                        progressText = "✅ 已完成 \(count) 张"
                        if autoSave { progressText += "（已保存到相册）" }
                    }
                case .imageReady(let url, let image):
                    downloaded.append((url, image))
                    await ImageCache.shared.set(image, for: url)
                case .error(let e):
                    await MainActor.run {
                        errorMessage = e.localizedDescription
                        showError = true
                    }
                }
            }
            
            // CoreData
            if let info = tweetInfo, !downloaded.isEmpty {
                let imgData = downloaded.map {
                    (url: $0.0.absoluteString, w: Int32($0.1.size.width), h: Int32($0.1.size.height))
                }
                CoreDataManager.shared.saveTweet(
                    tweetId: info.tweetId, tweetUrl: tweetURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    username: info.username, displayName: info.displayName,
                    tweetText: info.tweetText, createdAt: info.createdAt, images: imgData
                )
            }
            
            await MainActor.run { isDownloading = false }
        }
    }
}
 
extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}