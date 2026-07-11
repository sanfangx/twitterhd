import SwiftUI

/// 历史记录视图 (按相同推文作者自动聚合展示)
public struct HistoryView: View {
    @ObservedObject private var historyManager = HistoryManager.shared
    @Binding var selectedTab: Int
    @ObservedObject var downloaderViewModel: DownloaderViewModel
    
    public init(selectedTab: Binding<Int>, downloaderViewModel: DownloaderViewModel) {
        self._selectedTab = selectedTab
        self.downloaderViewModel = downloaderViewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                if historyManager.historyItems.isEmpty {
                    emptyHistoryView
                } else {
                    List {
                        ForEach(historyManager.groupedByAuthor()) { group in
                            Section {
                                ForEach(group.items) { item in
                                    historyRowView(for: item)
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        historyManager.delete(item: group.items[index])
                                    }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("@\(group.author)")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .textCase(nil)
                                    Spacer()
                                    Text("\(group.items.count) 条记录")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("解析历史")
            .toolbar {
                if !historyManager.historyItems.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            historyManager.clearAll()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }
    
    private func historyRowView(for item: TweetHistoryItem) -> some View {
        Button {
            // 点击历史链接自动带入首页并切换至抓取页面
            downloaderViewModel.inputURLText = item.urlString
            PhotoLibraryManager.shared.triggerTapHaptic()
            selectedTab = 0
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.urlString)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatDate(item.timestamp))
                        .font(.caption)
                    Spacer()
                    Text("点击带入解析")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无解析历史")
                .font(.headline)
                .foregroundColor(.primary)
            Text("每次解析推文时将自动记录并按作者智能归类。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
