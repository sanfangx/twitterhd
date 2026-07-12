import Foundation

/// 按作者分组的历史记录组，用于 HistoryView 的分组展示
public struct AuthorHistoryGroup: Identifiable {
    public var id: String { author }
    public let author: String
    public let items: [TweetHistoryItem]
}
