 import SwiftUI
 
 struct HistoryView: View {
     @State private var records: [TweetRecord] = []
     @State private var selectedRecord: TweetRecord?
     @State private var showDetail = false
     
     var body: some View {
         NavigationStack {
             Group {
                 if records.isEmpty {
                     VStack(spacing: 20) {
                         Image(systemName: "clock.arrow.circlepath")
                             .font(.system(size: 60))
                             .foregroundColor(.secondary)
                         Text("杩樻病鏈変笅杞借褰?)
                             .font(.title3)
                             .foregroundColor(.secondary)
                         Text("涓嬭浇鎺ㄦ枃鍥剧墖鍚庯紝璁板綍浼氭樉绀哄湪杩欓噷")
                             .font(.subheadline)
                             .foregroundStyle(.tertiary)
                     }
                 } else {
                     List {
                         ForEach(records, id: \.tweetId) { record in
                             Button {
                                 selectedRecord = record
                                 showDetail = true
                             } label: {
                                 HistoryRow(record: record)
                             }
                         }
                         .onDelete { indexSet in
                             for index in indexSet {
                                 CoreDataManager.shared.deleteTweet(records[index])
                             }
                             records.remove(atOffsets: indexSet)
                         }
                     }
                 }
             }
             .navigationTitle("鍘嗗彶璁板綍")
             .onAppear { refresh() }
             .sheet(isPresented: $showDetail) {
                 if let record = selectedRecord {
                     HistoryDetailView(record: record)
                 }
             }
         }
     }
     
     private func refresh() {
         records = CoreDataManager.shared.fetchHistory()
     }
 }
 
 // MARK: - 鍘嗗彶琛? 
 struct HistoryRow: View {
     let record: TweetRecord
     
     var body: some View {
         HStack(spacing: 12) {
             // 缂╃暐鍥?             if let firstImage = record.sortedImages.first,
                let url = URL(string: firstImage.imageUrl) {
                 AsyncImage(url: url) { phase in
                     switch phase {
                     case .success(let img):
                         img.resizable().scaledToFill()
                     default:
                         Color.gray
                     }
                 }
                 .frame(width: 60, height: 60)
                 .clipShape(RoundedRectangle(cornerRadius: 8))
             }
             
             VStack(alignment: .leading, spacing: 4) {
                 Text("@\(record.username)")
                     .font(.subheadline)
                     .fontWeight(.semibold)
                     .foregroundColor(.primary)
                 
                 if let text = record.tweetText {
                     Text(text)
                         .font(.caption)
                         .lineLimit(2)
                         .foregroundColor(.secondary)
                 }
                 
                 HStack(spacing: 8) {
                     Text(record.downloadedAt, style: .date)
                         .font(.caption2)
                         .foregroundStyle(.tertiary)
                     Text("\(record.sortedImages.count) 寮犲浘鐗?)
                         .font(.caption2)
                         .foregroundStyle(.tertiary)
                 }
             }
         }
         .padding(.vertical, 4)
     }
 }
 
 // MARK: - 鍘嗗彶璇︽儏
 
 struct HistoryDetailView: View {
     let record: TweetRecord
     @State private var showPreview = false
     @State private var previewIndex = 0
     @State private var previewImages: [UIImage] = []
     @AppStorage("autoSave") private var autoSave = true
     
     var body: some View {
         NavigationStack {
             ScrollView {
                 VStack(alignment: .leading, spacing: 12) {
                     // 鎺ㄦ枃淇℃伅
                     VStack(alignment: .leading, spacing: 4) {
                         Text("@\(record.username)")
                             .font(.headline)
                         if let text = record.tweetText {
                             Text(text)
                                 .font(.body)
                                 .foregroundColor(.secondary)
                         }
                         Text("涓嬭浇浜? ") + Text(record.downloadedAt, style: .date)
                             .font(.caption)
                             .foregroundStyle(.tertiary)
                     }
                     .padding(.horizontal)
                     
                     // 鍥剧墖缃戞牸
                     LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                         ForEach(Array(record.sortedImages.enumerated()), id: \.offset) { index, img in
                             if let url = URL(string: img.imageUrl) {
                                 AsyncImage(url: url) { phase in
                                     if let image = phase.image {
                                         image.resizable().scaledToFill()
                                     } else if phase.error != nil {
                                         Color.red
                                     } else {
                                         ProgressView()
                                     }
                                 }
                                 .frame(height: 150)
                                 .clipShape(RoundedRectangle(cornerRadius: 8))
                                 .onTapGesture {
                                     // 鍔犺浇鍥剧墖鍒?previewImages
                                     loadPreviewImages()
                                     previewIndex = index
                                     showPreview = true
                                 }
                             }
                         }
                     }
                     .padding(.horizontal)
                 }
             }
             .navigationTitle("鎺ㄦ枃璇︽儏")
             .navigationBarTitleDisplayMode(.inline)
             .fullScreenCover(isPresented: $showPreview) {
                 if !previewImages.isEmpty {
                     ImagePreviewView(images: previewImages, currentIndex: previewIndex, autoSave: autoSave)
                 }
             }
         }
     }
     
     private func loadPreviewImages() {
         // 浠庣紦瀛樻垨缃戠粶鍔犺浇鍥剧墖
         // 绠€鍖栧鐞嗭細鐢?UIImageView 鐨勫紓姝ュ姞杞?         previewImages = []
         for img in record.sortedImages {
             if let url = URL(string: img.imageUrl),
                let data = try? Data(contentsOf: url),
                let image = UIImage(data: data) {
                 previewImages.append(image)
             }
         }
     }
 }
