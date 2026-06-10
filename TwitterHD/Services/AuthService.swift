 import Foundation
 import WebKit
 
 // MARK: - AuthService
 
 @MainActor
 class AuthService: NSObject, ObservableObject {
     static let shared = AuthService()
     
     @Published var isLoggedIn: Bool = false
     
     private let keychainAccount = "XAuthCookies"
     private let keychainService = "com.twitterhd.auth"
     
     private override init() {
         super.init()
         isLoggedIn = loadCookies() != nil
     }
     
     // MARK: - Cookie 存储
     
     private var cachedCookies: [HTTPCookie]?
     
     /// 返回用于 X 请求的 cookies
     var cookiesForX: [HTTPCookie]? {
         if let cached = cachedCookies { return cached }
         cachedCookies = loadCookies()
         return cachedCookies
     }
     
     /// WKWebView 登录成功后调用
     func saveCookies(from webView: WKWebView) async {
         let store = webView.configuration.websiteDataStore.httpCookieStore
         let cookies = await store.allCookies()
         
         // 只需要 auth_token 和 ct0
         let needed = cookies.filter { $0.name == "auth_token" || $0.name == "ct0" }
         guard !needed.isEmpty else { return }
         
         // 序列化保存
         if let data = try? NSKeyedArchiver.archivedData(withRootObject: needed, requiringSecureCoding: false) {
             let query: [String: Any] = [
                 kSecClass as String: kSecClassGenericPassword,
                 kSecAttrService as String: keychainService,
                 kSecAttrAccount as String: keychainAccount,
                 kSecValueData as String: data,
                 kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
             ]
             SecItemDelete(query as CFDictionary)
             SecItemAdd(query as CFDictionary, nil)
         }
         
         cachedCookies = needed
         isLoggedIn = true
     }
     
     private func loadCookies() -> [HTTPCookie]? {
         let query: [String: Any] = [
             kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: keychainService,
             kSecAttrAccount as String: keychainAccount,
             kSecReturnData as String: true,
             kSecMatchLimit as String: kSecMatchLimitOne,
         ]
         var item: CFTypeRef?
         let status = SecItemCopyMatching(query as CFDictionary, &item)
         guard status == errSecSuccess, let data = item as? Data else { return nil }
         let cookies = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, HTTPCookie.self], from: data)
         return cookies as? [HTTPCookie]
     }
     
     func logout() {
         let query: [String: Any] = [
             kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: keychainService,
             kSecAttrAccount as String: keychainAccount,
         ]
         SecItemDelete(query as CFDictionary)
         cachedCookies = nil
         isLoggedIn = false
     }
 }
 
 // MARK: - Login ViewModel
 
 class LoginViewModel: NSObject, ObservableObject, WKNavigationDelegate {
     @Published var isLoading = false
     @Published var didSucceed = false
     @Published var errorMessage: String?
     
     private var webView: WKWebView?
     
     /// 创建 WKWebView 并配置监控
     func createWebView() -> WKWebView {
         let config = WKWebViewConfiguration()
         let webView = WKWebView(frame: .zero, configuration: config)
         webView.navigationDelegate = self
         self.webView = webView
         webView.load(URLRequest(url: URL(string: "https://x.com/login")!))
         return webView
     }
     
     func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
         // 每次页面变化时检查 cookies
         checkCookies(webView)
     }
     
     func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
         isLoading = false
         checkCookies(webView)
     }
     
     private func checkCookies(_ webView: WKWebView) {
         webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
             let hasAuth = cookies.contains { $0.name == "auth_token" && !$0.value.isEmpty }
             let hasCt0 = cookies.contains { $0.name == "ct0" && !$0.value.isEmpty }
             
             if hasAuth && hasCt0 {
                 Task { @MainActor in
                     await AuthService.shared.saveCookies(from: webView)
                     self?.didSucceed = true
                 }
             }
         }
     }
 }
