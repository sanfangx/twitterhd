import Foundation

/// 推文解析历史记录项
public struct TweetHistoryItem: Identifiable, Codable, Hashable {
    public let id: UUID
    /// 推文原始链接地址
    public let urlString: String
    /// 推文作者用户名 (不含 @)
    public let authorUsername: String
    /// 记录时间
    public let timestamp: Date
    
    public init(id: UUID = UUID(), urlString: String, authorUsername: String, timestamp: Date = Date()) {
        self.id = id
        self.urlString = urlString
        self.authorUsername = authorUsername.lowercased()
        self.timestamp = timestamp
    }
}
