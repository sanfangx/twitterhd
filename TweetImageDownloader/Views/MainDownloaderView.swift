import SwiftUI

/// 推文图片一键下载器主视图
public struct MainDownloaderView: View {
    @ObservedObject var viewModel: DownloaderViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    public init(viewModel: DownloaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        // 顶栏输入与解析操作区
                        topAddressBarView
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                            .zIndex(1)
                        
                        // 错误提示区
                        if let errorMessage = viewModel.errorMessage {
                            errorBanner(text: errorMessage)
                        }
                        
                        // 中间画质网格展示区
                        ScrollView {
                            if viewModel.isParsing {
                                loadingStateView
                            } else if viewModel.images.isEmpty {
                                emptyStateView
                            } else {
                                imageGridView
                            }
                        }
                    }
                    
                    // 底部浮动全选与下载控制条
                    if !viewModel.images.isEmpty {
                        bottomActionBarView
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // 顶部轻量免打扰自动消失的成功提示 Toast
                if viewModel.showSuccessBanner {
                    successToastBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationTitle("推文原图抓取")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 顶栏地址输入与操作按钮
    private var topAddressBarView: some View {
        HStack(spacing: 8) {
            // 输入栏地址框
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                
                TextField("粘贴推文链接 ( https://x.com/... )", text: $viewModel.inputURLText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                
                if !viewModel.inputURLText.isEmpty {
                    Button {
                        viewModel.inputURLText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // 粘贴键
            Button(action: viewModel.pasteFromClipboard) {
                Text("粘贴")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
            
            // 解析键
            Button(action: viewModel.parseTweet) {
                if viewModel.isParsing {
                    ProgressView()
                        .tint(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(10)
                } else {
                    Text("解析")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(viewModel.isParsing)
        }
    }
    
    // MARK: - 图片网格展示
    private var imageGridView: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach($viewModel.images) { $item in
                TweetImageCardView(item: $item)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 110) // 为底部控制条保留空间
    }
    
    // MARK: - 底部全选与下载控制条
    private var bottomActionBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center, spacing: 14) {
                // 全选 / 取消全选按钮
                Button(action: viewModel.toggleSelectAll) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isAllSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.isAllSelected ? .blue : .secondary)
                            .font(.title3)
                        Text(viewModel.isAllSelected ? "取消全选" : "全选全部")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                Text("已选 \(viewModel.selectedCount)/\(viewModel.images.count) 张")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                // 下载按键
                Button(action: viewModel.downloadSelectedImages) {
                    HStack(spacing: 6) {
                        if viewModel.isDownloading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.to.line.compact")
                        }
                        Text(viewModel.isDownloading ? "保存中..." : "下载 4K 原图")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(viewModel.selectedCount == 0 || viewModel.isDownloading ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.selectedCount == 0 || viewModel.isDownloading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: -2)
    }
    
    // MARK: - 状态占位视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54))
                .foregroundColor(.secondary.opacity(0.6))
            Text("推文高清原图轻松抓取")
                .font(.headline)
                .foregroundColor(.primary)
            Text("粘贴 Twitter/X 链接并点击“解析”，即可预览作者发布的所有配图并一键以最高清晰度保存至相册。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 100)
            ProgressView()
                .scaleEffect(1.4)
            Text("正在隐式渲染并抓取作者卡片原图...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func errorBanner(text: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(text)
                .font(.footnote)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var successToastBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
            Text("成功将 \(viewModel.downloadedCountResult) 张原图保存至系统相册！")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// 单张推文卡片预览组件
private struct TweetImageCardView: View {
    @Binding var item: TweetImageItem
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 预览图加载 (利用等比居中裁剪 scaledToFill 保障任何非正方形原图都不会拉伸变形)
            AsyncImage(url: item.previewURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(ProgressView())
                case .success(let image):
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            image
                                .resizable()
                                .scaledToFill()
                        )
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .cornerRadius(12)
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    item.isSelected.toggle()
                }
                PhotoLibraryManager.shared.triggerTapHaptic()
            }
            
            // 右上角勾选复选框
            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    item.isSelected.toggle()
                }
                PhotoLibraryManager.shared.triggerTapHaptic()
            } label: {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle.fill")
                    .font(.title2)
                    .foregroundColor(item.isSelected ? .blue : Color.black.opacity(0.45))
                    .background(Circle().fill(Color.white).frame(width: 22, height: 22))
                    .padding(8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
