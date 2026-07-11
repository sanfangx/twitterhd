import Foundation
import Photos
import UIKit

/// 负责将 4K 高清原图批量并发保存至系统相册，并提供触觉反馈的服务类
public final class PhotoLibraryManager {
    public static let shared = PhotoLibraryManager()
    
    private init() {}
    
    /// 检查并请求系统相册添加权限
    public func requestAddOnlyPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }
    
    /// 批量下载并发保存 4K 原图到系统相册
    /// - Parameters:
    ///   - items: 待保存的推文图片模型数组
    ///   - progressHandler: 下载进度回调，参数 (当前已完成张数, 总张数)
    /// - Returns: 保存成功的数量
    public func saveOriginalImages(
        _ items: [TweetImageItem],
        progressHandler: @escaping @MainActor (Int, Int) -> Void
    ) async throws -> Int {
        let hasPermission = await requestAddOnlyPermission()
        guard hasPermission else {
            throw NSError(domain: "PhotoLibraryError", code: 401, userInfo: [NSLocalizedDescriptionKey: "无系统相册写入权限，请前往 iOS 设置开启"])
        }
        
        let total = items.count
        var completedCount = 0
        var successCount = 0
        
        // 分张顺序或并发下载写入相册
        for item in items {
            do {
                let (data, response) = try await URLSession.shared.data(from: item.originalURL)
                if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                    try await saveImageDataToAlbum(data)
                    successCount += 1
                }
            } catch {
                print("单张下载保存失败: \(item.originalURL), err: \(error)")
            }
            completedCount += 1
            await progressHandler(completedCount, total)
        }
        
        // 触发触控振动反馈
        await triggerSuccessHaptic()
        return successCount
    }
    
    /// 将图片数据写入 iOS 相册
    private func saveImageDataToAlbum(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: data, options: options)
        }
    }
    
    /// 触发成功反馈振动
    @MainActor
    public func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// 触发点击振动
    @MainActor
    public func triggerTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
