 import CoreData
 
 // MARK: - NSManagedObject 子类
 
 @objc(TweetRecord)
 public class TweetRecord: NSManagedObject {
     @NSManaged public var tweetId: String
     @NSManaged public var tweetUrl: String
     @NSManaged public var username: String
     @NSManaged public var userDisplayName: String?
     @NSManaged public var userAvatarUrl: String?
     @NSManaged public var tweetText: String?
     @NSManaged public var createdAt: Date
     @NSManaged public var downloadedAt: Date
     @NSManaged public var images: NSSet?
 }
 
 @objc(TweetImage)
 public class TweetImage: NSManagedObject {
     @NSManaged public var imageUrl: String
     @NSManaged public var localFilePath: String?
     @NSManaged public var width: Int32
     @NSManaged public var height: Int32
     @NSManaged public var sortIndex: Int32
     @NSManaged public var tweet: TweetRecord?
 }
 
 // MARK: - CoreDataManager
 
 class CoreDataManager {
     static let shared = CoreDataManager()
     private init() {}
     
     lazy var persistentContainer: NSPersistentContainer = {
         let container = NSPersistentContainer(name: "TwitterHD", managedObjectModel: model)
         let storeURL = FileManager.default
             .urls(for: .documentDirectory, in: .userDomainMask).first!
             .appendingPathComponent("TwitterHD.sqlite")
         let storeDescription = NSPersistentStoreDescription(url: storeURL)
         container.persistentStoreDescriptions = [storeDescription]
         container.loadPersistentStores { _, error in
             if let error = error { fatalError("Core Data 加载失败: \(error)") }
         }
         return container
     }()
     
     var context: NSManagedObjectContext { persistentContainer.viewContext }
     
     // MARK: - 程序化 Core Data 模型
     
     private var model: NSManagedObjectModel {
         let model = NSManagedObjectModel()
         let tweetEntity = NSEntityDescription()
         tweetEntity.name = "TweetRecord"
         tweetEntity.managedObjectClassName = "TweetRecord"
         tweetEntity.properties = [
             attr("tweetId", .stringAttributeType, false),
             attr("tweetUrl", .stringAttributeType, false),
             attr("username", .stringAttributeType, false),
             attr("userDisplayName", .stringAttributeType, true),
             attr("userAvatarUrl", .stringAttributeType, true),
             attr("tweetText", .stringAttributeType, true),
             attr("createdAt", .dateAttributeType, false),
             attr("downloadedAt", .dateAttributeType, false),
         ]
         
         let imageEntity = NSEntityDescription()
         imageEntity.name = "TweetImage"
         imageEntity.managedObjectClassName = "TweetImage"
         imageEntity.properties = [
             attr("imageUrl", .stringAttributeType, false),
             attr("localFilePath", .stringAttributeType, true),
             attr("width", .integer32AttributeType, false),
             attr("height", .integer32AttributeType, false),
             attr("sortIndex", .integer32AttributeType, false),
         ]
         
         // Relationship
         let tweetImagesRel = NSRelationshipDescription()
         tweetImagesRel.name = "images"; tweetImagesRel.destinationEntity = imageEntity
         tweetImagesRel.isOptional = true; tweetImagesRel.maxCount = 0
         tweetImagesRel.deleteRule = .cascadeDeleteRule
         
         let imageTweetRel = NSRelationshipDescription()
         imageTweetRel.name = "tweet"; imageTweetRel.destinationEntity = tweetEntity
         imageTweetRel.isOptional = true; imageTweetRel.maxCount = 1
         imageTweetRel.deleteRule = .nullifyDeleteRule
         
         tweetImagesRel.inverseRelationship = imageTweetRel
         imageTweetRel.inverseRelationship = tweetImagesRel
         
         tweetEntity.properties.append(tweetImagesRel)
         imageEntity.properties.append(imageTweetRel)
         
         model.entities = [tweetEntity, imageEntity]
         return model
     }
     
     private func attr(_ name: String, _ type: NSAttributeType, _ optional: Bool) -> NSAttributeDescription {
         let a = NSAttributeDescription()
         a.name = name; a.attributeType = type; a.isOptional = optional
         return a
     }
     
     // MARK: - CRUD
     
     func saveTweet(tweetId: String, tweetUrl: String, username: String,
                    displayName: String?, tweetText: String?,
                    createdAt: Date, images: [(url: String, w: Int32, h: Int32)]) -> TweetRecord {
         let record = TweetRecord(context: context)
         record.tweetId = tweetId; record.tweetUrl = tweetUrl
         record.username = username; record.userDisplayName = displayName
         record.tweetText = tweetText; record.createdAt = createdAt
         record.downloadedAt = Date()
         for (i, img) in images.enumerated() {
             let image = TweetImage(context: context)
             image.imageUrl = img.url; image.width = img.w
             image.height = img.h; image.sortIndex = Int32(i)
             image.tweet = record
         }
         try? context.save(); return record
     }
     
     func fetchHistory() -> [TweetRecord] {
         let req = NSFetchRequest<TweetRecord>(entityName: "TweetRecord")
         req.sortDescriptors = [NSSortDescriptor(key: "downloadedAt", ascending: false)]
         return (try? context.fetch(req)) ?? []
     }
     
     func deleteTweet(_ tweet: TweetRecord) {
         context.delete(tweet); try? context.save()
     }
 }
 
 extension TweetRecord {
     var sortedImages: [TweetImage] {
         guard let s = images as? Set<TweetImage> else { return [] }
         return s.sorted { $0.sortIndex < $1.sortIndex }
     }
 }
