import Foundation
import UIKit
import SwiftUI

/// 主界面下载与推文解析相关的视图模型
@MainActor
public final class DownloaderViewModel: ObservableObject {
    /// 顶部地址栏输入的推文链接
    @Published public var inputURLText: String = ""
    /// 是否正处于解析状态中
    @Published public var isParsing: Bool = false
    /// 当前解析到的图片数组
    @Published public var images: [TweetImageItem] = []
    /// 错误或者提示信息
    @Published public var errorMessage: String? = nil
    /// 是否正处于保存下载到相册的状态中
    @Published public var isDownloading: Bool = false
    /// 下载进度描述文案 (例如: "正在保存 2/4 张原图...")
    @Published public var downloadProgressText: String? = nil
    /// 是否展示下载成功横幅
    @Published public var showSuccessBanner: Bool = false
    @Published public var downloadedCountResult: Int = 0
    
    public init() {}
    
    /// 将剪贴板中的链接一键替换至输入栏
    public func pasteFromClipboard() {
        PhotoLibraryManager.shared.triggerTapHaptic()
        if let string = UIPasteboard.general.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.inputURLText = string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// 解析输入栏的推文链接
    public func parseTweet() {
        PhotoLibraryManager.shared.triggerTapHaptic()
        let text = inputURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            self.errorMessage = "请先输入或粘贴 Twitter/X 推文链接"
            return
        }
        
        self.errorMessage = nil
        self.isParsing = true
        self.images.removeAll()
        
        Task {
            do {
                let extracted = try await TwitterWebViewService.shared.parseTweetImages(from: text)
                self.images = extracted
                self.isParsing = false
                let author = extracted.first?.authorUsername ?? "unknown"
                HistoryManager.shared.addHistory(urlString: text, authorUsername: author)
            } catch {
                self.isParsing = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// 切换全选 / 取消全选
    public func toggleSelectAll() {
        PhotoLibraryManager.shared.triggerTapHaptic()
        let allSelected = images.allSatisfy { $0.isSelected }
        for i in images.indices {
            images[i].isSelected = !allSelected
        }
    }
    
    /// 已选中的张数
    public var selectedCount: Int {
        return images.filter { $0.isSelected }.count
    }
    
    /// 是否全都已经选中
    public var isAllSelected: Bool {
        return !images.isEmpty && images.allSatisfy { $0.isSelected }
    }
    
    /// 一键下载所有已选中的 4K 原图入相册
    public func downloadSelectedImages() {
        let selected = images.filter { $0.isSelected }
        guard !selected.isEmpty else {
            self.errorMessage = "请至少选择一张要下载的原图"
            return
        }
        
        PhotoLibraryManager.shared.triggerTapHaptic()
        self.isDownloading = true
        self.errorMessage = nil
        self.downloadProgressText = "准备保存 0/\(selected.count) 张原图..."
        
        Task {
            do {
                let successCount = try await PhotoLibraryManager.shared.saveOriginalImages(selected) { completed, total in
                    self.downloadProgressText = "正在保存原图 \(completed)/\(total) 张..."
                }
                self.isDownloading = false
                self.downloadProgressText = nil
                self.downloadedCountResult = successCount
                withAnimation {
                    self.showSuccessBanner = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    withAnimation {
                        self.showSuccessBanner = false
                    }
                }
            } catch {
                self.isDownloading = false
                self.downloadProgressText = nil
                self.errorMessage = "保存至相册失败: \(error.localizedDescription)"
            }
        }
    }
}
