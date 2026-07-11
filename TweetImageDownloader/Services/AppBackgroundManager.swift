import SwiftUI
import UIKit

/// 自定义应用背景管理器
public class AppBackgroundManager: ObservableObject {
    public static let shared = AppBackgroundManager()
    
    @Published public var customBackgroundImage: UIImage?
    
    private let backgroundFilename = "custom_app_background.jpg"
    
    private init() {
        loadCustomBackground()
    }
    
    private var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(backgroundFilename)
    }
    
    /// 从本地文档目录加载自定义背景图
    public func loadCustomBackground() {
        guard let url = fileURL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            customBackgroundImage = nil
            return
        }
        customBackgroundImage = image
    }
    
    /// 保存选择的相册图片作为自定义背景
    public func saveCustomBackground(imageData: Data) {
        guard let url = fileURL else { return }
        do {
            try imageData.write(to: url)
            if let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self.customBackgroundImage = image
                }
            }
        } catch {
            print("保存自定义背景失败: \(error)")
        }
    }
    
    /// 清除自定义背景恢复系统默认
    public func clearCustomBackground() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
        DispatchQueue.main.async {
            self.customBackgroundImage = nil
        }
    }
}
