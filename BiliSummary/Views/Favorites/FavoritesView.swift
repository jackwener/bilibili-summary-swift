import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @StateObject private var viewModel: FavoritesViewModel

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
    }

    // MARK: - Not Logged In

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("请先登录 Bilibili")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("登录后可浏览收藏夹并批量总结")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button("去登录") {
                showLogin = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.biliPink)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }

    @State private var showLogin = false

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
                VStack(spacing: 8) {
                    HStack {
                        Text("总结进度")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(viewModel.homeVM.completedCount)/\(viewModel.homeVM.totalCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: Double(viewModel.homeVM.completedCount),
                                 total: Double(max(viewModel.homeVM.totalCount, 1)))
                        .tint(Color.biliPink)

                    // Show currently processing items
                    let active = viewModel.homeVM.progressItems.filter { $0.status == .processing }
                    if !active.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(active) { item in
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.mini)
                                    Text(item.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.message)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))

                Divider()
            }

            // Videos List
            if viewModel.isLoadingVideos && viewModel.videos.isEmpty {
                Spacer()
                ProgressView("加载视频...")
                Spacer()
            } else if viewModel.videos.isEmpty {
                Spacer()
                Text("收藏夹为空")
                    .foregroundStyle(.secondary)
                Spacer()
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
                            SummaryDetailView(item: item, viewModel: SummaryListViewModel())
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
                        StorageService.shared.addUserFavorite(
                            uid: video.upperMid,
                            name: video.upperName
                        )
                    } label: {
                        Label("收藏 UP", systemImage: "person.badge.plus")
                    }
                    .tint(.blue)
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
