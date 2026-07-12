import Foundation

/// 解析历史记录管理器 (长期持久化，按作者自动归类)
public class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()
    
    @Published public private(set) var historyItems: [TweetHistoryItem] = []
    
    private let historyFilename = "tweet_parse_history.json"
    
    private init() {
        loadHistory()
    }
    
    private var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(historyFilename)
    }
    
    /// 从本地加载历史记录
    public func loadHistory() {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([TweetHistoryItem].self, from: data) else {
            historyItems = []
            return
        }
        historyItems = items.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    /// 添加或更新解析历史
    public func addHistory(urlString: String, authorUsername: String) {
        let cleanedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedURL.isEmpty else { return }
        
        let author = authorUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let effectiveAuthor = author.isEmpty ? "unknown" : author
        
        // 移除旧有相同链接
        var current = historyItems.filter { $0.urlString.lowercased() != cleanedURL.lowercased() }
        let newItem = TweetHistoryItem(urlString: cleanedURL, authorUsername: effectiveAuthor, timestamp: Date())
        current.insert(newItem, at: 0)
        
        DispatchQueue.main.async {
            self.historyItems = current
            self.saveHistory()
        }
    }
    
    /// 按相同推特作者将历史记录自动分组，并按最后活动时间降序排列
    public func groupedByAuthor() -> [AuthorHistoryGroup] {
        let groupedDictionary = Dictionary(grouping: historyItems, by: { $0.authorUsername })
        return groupedDictionary.map { (key, value) in
            let sortedItems = value.sorted(by: { $0.timestamp > $1.timestamp })
            return AuthorHistoryGroup(author: key, items: sortedItems)
        }.sorted { group1, group2 in
            let date1 = group1.items.first?.timestamp ?? Date.distantPast
            let date2 = group2.items.first?.timestamp ?? Date.distantPast
            return date1 > date2
        }
    }
    
    /// 删除单条历史
    public func delete(item: TweetHistoryItem) {
        historyItems.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    /// 删除某个作者的所有历史
    public func deleteAuthor(_ author: String) {
        historyItems.removeAll { $0.authorUsername == author }
        saveHistory()
    }
    
    /// 清空所有历史
    public func clearAll() {
        historyItems.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        guard let url = fileURL,
              let data = try? JSONEncoder().encode(historyItems) else { return }
        try? data.write(to: url)
    }
}
