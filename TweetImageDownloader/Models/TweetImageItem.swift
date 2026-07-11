import Foundation

/// 推文抓取到的单张图片模型
public struct TweetImageItem: Identifiable, Hashable, Codable {
    public let id: UUID
    /// 预览图片 URL（使用 name=medium 或小画质提升网格浏览速度）
    public let previewURL: URL
    /// 4K 高清原图 URL（通过参数替换为 name=4096x4096）
    public let originalURL: URL
    /// 目标推文作者用户名 (不含 @)
    public let authorUsername: String
    /// 当前是否被选中（便于多选/全选操作）
    public var isSelected: Bool
    
    public init(
        id: UUID = UUID(),
        previewURL: URL,
        originalURL: URL,
        authorUsername: String,
        isSelected: Bool = true
    ) {
        self.id = id
        self.previewURL = previewURL
        self.originalURL = originalURL
        self.authorUsername = authorUsername
        self.isSelected = isSelected
    }
}
