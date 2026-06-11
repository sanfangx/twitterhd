import UIKit
 
class BackgroundManager: ObservableObject {
    static let shared = BackgroundManager()
    
    @Published var image: UIImage?
    
    private let filename = "background.jpg"
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }
    
    var hasImage: Bool { FileManager.default.fileExists(atPath: fileURL.path) }
    
    private init() { load() }
    
    func save(_ img: UIImage) {
        if let data = img.jpegData(compressionQuality: 0.7) {
            try? data.write(to: fileURL)
            image = img
        }
    }
    
    func load() {
        if let data = try? Data(contentsOf: fileURL) { image = UIImage(data: data) }
    }
    
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        image = nil
    }
}
