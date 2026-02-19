import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @StateObject private var viewModel: FavoritesViewModel
    @ObservedObject private var userFavVM = UserFavoritesViewModel.shared
    @StateObject private var toastVM = ToastViewModel()
    @State private var showLogin = false

    init(homeVM: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(homeVM: homeVM))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isLoggedIn {
                    notLoggedInView
                } else if viewModel.isLoadingFolders {
                    ProgressView("加载收藏夹...")
                } else {
                    favoritesContent
                }
            }
            .navigationTitle("收藏夹")
            .onAppear {
                if auth.isLoggedIn && viewModel.folders.isEmpty {
                    Task {
                        if let cred = auth.credential {
                            await viewModel.loadFolders(credential: cred)
                        }
                    }
                }
            }
        }
        .toast(isPresented: $toastVM.isPresented, message: toastVM.message)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }

    // MARK: - Not Logged In

    private var notLoggedInView: some View {
        EmptyStateView(
            icon: "person.crop.circle.badge.questionmark",
            title: "请先登录 Bilibili",
            subtitle: "登录后可浏览收藏夹并批量总结",
            actionTitle: "去登录",
            action: { showLogin = true }
        )
    }

    // MARK: - Favorites Content

    private var favoritesContent: some View {
        VStack(spacing: 0) {
            // Folder Picker
            if !viewModel.folders.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.folders) { folder in
                            folderChip(folder)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))

                Divider()
            }

            // Batch summarization progress
            if viewModel.homeVM.isProcessing {
                ProgressSectionView(homeVM: viewModel.homeVM)
                    .padding(.top, 8)

                Divider()
            }

            // Videos List
            if viewModel.isLoadingVideos && viewModel.videos.isEmpty {
                Spacer()
                ProgressView("加载视频...")
                Spacer()
            } else if viewModel.videos.isEmpty {
                EmptyStateView(
                    icon: "star",
                    title: "收藏夹为空"
                )
            } else {
                videosList
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        if let cred = auth.credential {
                            await viewModel.summarizeUnsummarized(credential: cred)
                        }
                    }
                } label: {
                    Label("全部总结", systemImage: "sparkles")
                }
                .disabled(viewModel.homeVM.isProcessing)
            }
        }
    }

    // MARK: - Folder Chip

    private func folderChip(_ folder: FavoriteFolder) -> some View {
        Button {
            Task {
                if let cred = auth.credential {
                    await viewModel.selectFolder(folder, credential: cred)
                }
            }
        } label: {
            HStack(spacing: 4) {
                if folder.isDefault {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                }
                Text(folder.title)
                    .font(.subheadline)
                Text("\(folder.mediaCount)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                viewModel.selectedFolder?.id == folder.id
                    ? Color.biliPink.opacity(0.15)
                    : Color(.systemGray6)
            )
            .foregroundStyle(
                viewModel.selectedFolder?.id == folder.id ? Color.biliPink : .primary
            )
            .clipShape(Capsule())
        }
    }

    // MARK: - Videos List

    private var videosList: some View {
        List {
            ForEach(viewModel.videos) { video in
                let status = viewModel.summaryStatus[video.bvid] ?? .none

                Group {
                    if status == .done,
                       let relPath = StorageService.shared.findSummaryRelativePath(
                           title: video.title,
                           outputSubdir: Constants.favoritesSubdir
                       ) {
                        let item = StorageService.SummaryItem(
                            id: relPath,
                            title: video.title,
                            relativePath: relPath,
                            bvid: video.bvid,
                            cover: video.coverURL?.absoluteString ?? "",
                            duration: 0,
                            authorName: video.upperName,
                            authorUID: video.upperMid,
                            hasSubtitle: true,
                            date: nil
                        )
                        NavigationLink {
                            SummaryDetailView(item: item, viewModel: SummaryListViewModel.shared)
                        } label: {
                            FavoriteVideoRow(
                                video: video,
                                status: status,
                                onSummarize: {}
                            )
                        }
                    } else {
                        FavoriteVideoRow(
                            video: video,
                            status: status,
                            onSummarize: {
                                Task {
                                    if let cred = auth.credential {
                                        await viewModel.summarizeSelected(bvids: [video.bvid], credential: cred)
                                    }
                                }
                            }
                        )
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            if let cred = auth.credential {
                                try? await viewModel.unfavorite(bvid: video.bvid, credential: cred)
                            }
                        }
                    } label: {
                        Label("取消收藏", systemImage: "star.slash")
                    }

                    Button {
                        if userFavVM.isFavorited(uid: video.upperMid) {
                            userFavVM.removeFavorite(uid: video.upperMid)
                            toastVM.show("已取消收藏 \(video.upperName)")
                        } else {
                            userFavVM.addFavorite(
                                uid: video.upperMid,
                                name: video.upperName
                            )
                            toastVM.show("已收藏 \(video.upperName)")
                        }
                    } label: {
                        Label(
                            userFavVM.isFavorited(uid: video.upperMid) ? "取消收藏 UP" : "收藏 UP",
                            systemImage: userFavVM.isFavorited(uid: video.upperMid) ? "person.badge.minus" : "person.badge.plus"
                        )
                    }
                    .tint(userFavVM.isFavorited(uid: video.upperMid) ? .orange : .blue)
                }
                .onAppear {
                    if video.id == viewModel.videos.last?.id {
                        Task {
                            if let cred = auth.credential {
                                await viewModel.loadMore(credential: cred)
                            }
                        }
                    }
                }
            }

            if viewModel.isLoadingVideos {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Favorite Video Row

struct FavoriteVideoRow: View {
    let video: FavoriteVideo
    let status: FavoritesViewModel.SummaryState
    let onSummarize: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            CachedAsyncImage(url: video.coverURL, cornerRadius: 8)
                .frame(width: 120, height: 68)
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(video.upperName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(video.durationFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Status
                HStack(spacing: 4) {
                    statusBadge
                }
            }

            Spacer()

            // Action — show retry for none, noSubtitle, and failed
            if status == .none || status == .noSubtitle {
                Button(action: onSummarize) {
                    Image(systemName: status == .none ? "sparkles" : "arrow.clockwise")
                        .foregroundStyle(Color.biliPink)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .done:
            Label("已总结", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .noSubtitle:
            Label("无字幕", systemImage: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .processing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("处理中")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .none:
            EmptyView()
        }
    }
}
