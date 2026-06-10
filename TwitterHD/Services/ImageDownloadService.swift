 import Foundation
 import UIKit
 import Photos
 
 // MARK: - 下载状态
 
 enum DownloadEvent {
     case started(Int)       // 共几张
     case progress(Int, Int) // 当前第几张, 共几张
     case completed(Int)     // 完成了几张
     case imageReady(URL, UIImage) // 某张图片下载完成
     case error(Error)
 }
 
 // MARK: - ImageDownloadService
 
 actor ImageDownloadService {
     static let shared = ImageDownloadService()
     private init() {}
     
     private let session: URLSession = {
         let config = URLSessionConfiguration.default
         config.timeoutIntervalForRequest = 30
         config.timeoutIntervalForResource = 120
         return URLSession(configuration: config)
     }()
     
     /// 下载所有图片，返回 AsyncStream 提供进度
     func downloadImages(_ urls: [URL], autoSave: Bool) -> AsyncStream<DownloadEvent> {
         AsyncStream { continuation in
             Task {
                 continuation.yield(.started(urls.count))
                 var completed = 0
                 for (index, url) in urls.enumerated() {
                     do {
                         continuation.yield(.progress(index + 1, urls.count))
                         let image = try await downloadSingleImage(from: url)
                         continuation.yield(.imageReady(url, image))
                         
                         if autoSave {
                             try await saveToPhotoAlbum(image: image)
                         }
                         
                         completed += 1
                     } catch {
                         continuation.yield(.error(error))
                     }
                 }
                 continuation.yield(.completed(completed))
                 continuation.finish()
             }
         }
     }
     
     private func downloadSingleImage(from url: URL) async throws -> UIImage {
         let request = URLRequest(url: url, timeoutInterval: 30)
         let (data, response) = try await session.data(for: request)
         guard let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let image = UIImage(data: data) else {
             throw ImageError.downloadFailed
         }
         return image
     }
     
     /// 保存到相册
     private func saveToPhotoAlbum(image: UIImage) async throws {
         let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
         guard status == .authorized || status == .limited else {
             throw ImageError.noPermission
         }
         
         try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
             PHPhotoLibrary.shared().performChanges {
                 PHAssetChangeRequest.creationRequestForAsset(from: image)
             } completionHandler: { success, error in
                 if success { continuation.resume() }
                 else { continuation.resume(throwing: error ?? ImageError.saveFailed) }
             }
         }
     }
     
     /// 手动保存单张图片（供手动模式使用）
     func saveImageManually(_ image: UIImage) async throws {
         try await saveToPhotoAlbum(image: image)
     }
 }
 
 enum ImageError: LocalizedError {
     case downloadFailed, saveFailed, noPermission
     
     var errorDescription: String? {
         switch self {
         case .downloadFailed: return "图片下载失败"
         case .saveFailed: return "保存到相册失败"
         case .noPermission: return "没有相册访问权限"
         }
     }
 }
