 import SwiftUI
 
 struct ImagePreviewView: View {
     let images: [UIImage]
     @State var currentIndex: Int
     let autoSave: Bool
     @Environment(\.dismiss) private var dismiss
     @State private var savedIndices: Set<Int> = []
     @State private var showToast = false
     @State private var toastMessage = ""
     
     var body: some View {
         ZStack {
             Color.black.ignoresSafeArea()
             
             TabView(selection: $currentIndex) {
                 ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                     ZoomableImageView(image: image)
                         .tag(index)
                 }
             }
             .tabViewStyle(.page(indexDisplayMode: .automatic))
             
             // 顶部工具栏
             VStack {
                 HStack {
                     Button {
                         dismiss()
                     } label: {
                         Image(systemName: "xmark")
                             .font(.title2)
                             .foregroundColor(.white)
                             .padding(8)
                             .background(.ultraThinMaterial)
                             .clipShape(Circle())
                     }
                     
                     Spacer()
                     
                     Text("\(currentIndex + 1) / \(images.count)")
                         .foregroundColor(.white)
                         .font(.subheadline)
                         .padding(.horizontal, 12)
                         .padding(.vertical, 6)
                         .background(.ultraThinMaterial)
                         .cornerRadius(12)
                     
                     Spacer()
                     
                     Button {
                         saveCurrentImage()
                     } label: {
                         Image(systemName: savedIndices.contains(currentIndex) ? "checkmark.circle.fill" : "square.and.arrow.down")
                             .font(.title2)
                             .foregroundColor(savedIndices.contains(currentIndex) ? .green : .white)
                             .padding(8)
                             .background(.ultraThinMaterial)
                             .clipShape(Circle())
                     }
                 }
                 .padding()
                 
                 Spacer()
             }
             
             // Toast
             if showToast {
                 VStack {
                     Spacer()
                     Text(toastMessage)
                         .foregroundColor(.white)
                         .padding(.horizontal, 20)
                         .padding(.vertical, 10)
                         .background(.ultraThinMaterial)
                         .cornerRadius(20)
                         .padding(.bottom, 40)
                 }
                 .transition(.move(edge: .bottom).combined(with: .opacity))
                 .animation(.spring, value: showToast)
             }
         }
     }
     
     private func saveCurrentImage() {
         guard currentIndex < images.count, !savedIndices.contains(currentIndex) else { return }
         let image = images[currentIndex]
         Task {
             do {
                 try await ImageDownloadService.shared.saveImageManually(image)
                 await MainActor.run {
                     savedIndices.insert(currentIndex)
                     toastMessage = "已保存到相册"
                     showToast = true
                     DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                         showToast = false
                     }
                 }
             } catch {
                 await MainActor.run {
                     toastMessage = "保存失败"
                     showToast = true
                     DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                         showToast = false
                     }
                 }
             }
         }
     }
 }
 
 // MARK: - 可缩放图片视图
 
 struct ZoomableImageView: UIViewRepresentable {
     let image: UIImage
     
     func makeUIView(context: Context) -> UIScrollView {
         let scrollView = UIScrollView()
         scrollView.minimumZoomScale = 1.0
         scrollView.maximumZoomScale = 5.0
         scrollView.delegate = context.coordinator
         scrollView.showsHorizontalScrollIndicator = false
         scrollView.showsVerticalScrollIndicator = false
         
         let imageView = UIImageView(image: image)
         imageView.contentMode = .scaleAspectFit
         imageView.frame = scrollView.bounds
         imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
         scrollView.addSubview(imageView)
         return scrollView
     }
     
     func updateUIView(_ uiView: UIScrollView, context: Context) {}
     
     func makeCoordinator() -> Coordinator { Coordinator() }
     
     class Coordinator: NSObject, UIScrollViewDelegate {
         func viewForZooming(in scrollView: UIScrollView) -> UIView? {
             scrollView.subviews.first
         }
     }
 }
