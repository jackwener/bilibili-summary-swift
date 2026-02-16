import Foundation

// MARK: - Favorites ViewModel

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var folders: [FavoriteFolder] = []
    @Published var selectedFolder: FavoriteFolder?
    @Published var videos: [FavoriteVideo] = []
    @Published var isLoadingFolders = false
    @Published var isLoadingVideos = false
    @Published var currentPage = 1
    @Published var hasMore = false
    @Published var errorMessage: String?

    // Summary status tracking
    @Published var summaryStatus: [String: SummaryState] = [:]  // bvid -> status

    enum SummaryState {
        case none, done, noSubtitle, processing
    }

    let homeVM: HomeViewModel

    private let biliAPI = BilibiliAPI.shared
    private let storage = StorageService.shared

    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
    }

    // MARK: - Load Folders

    func loadFolders(credential: BiliCredential) async {
        isLoadingFolders = true
        errorMessage = nil

        do {
            let selfInfo = try await biliAPI.getSelfInfo(credential: credential)
            folders = try await biliAPI.getFavoriteFolders(uid: selfInfo.mid, credential: credential)

            // Auto-select default folder
            if let defaultFolder = folders.first(where: \.isDefault) ?? folders.first {
                await selectFolder(defaultFolder, credential: credential)
            }
        } catch {
            errorMessage = "加载收藏夹失败: \(error.localizedDescription)"
        }

        isLoadingFolders = false
    }

    // MARK: - Select Folder

    func selectFolder(_ folder: FavoriteFolder, credential: BiliCredential) async {
        selectedFolder = folder
        videos = []
        currentPage = 1
        hasMore = false
        await loadVideos(credential: credential)
    }

    // MARK: - Load Videos

    func loadVideos(credential: BiliCredential) async {
        guard let folder = selectedFolder else { return }

        isLoadingVideos = true
        errorMessage = nil

        do {
            let (newVideos, more) = try await biliAPI.getFavoriteVideos(
                mediaId: folder.id,
                page: currentPage,
                credential: credential
            )

            videos.append(contentsOf: newVideos)
            hasMore = more

            // Check summary status for each video
            for video in newVideos {
                let safe = Summary.sanitizeFilename(video.title)
                let normalPath = storage.summaryRoot
                    .appendingPathComponent(Constants.favoritesSubdir)
                    .appendingPathComponent("\(safe).md")
                let nosubPath = storage.summaryRoot
                    .appendingPathComponent(Constants.favoritesSubdir)
                    .appendingPathComponent("no_subtitle/\(safe).md")

                if FileManager.default.fileExists(atPath: normalPath.path) {
                    summaryStatus[video.bvid] = .done
                } else if FileManager.default.fileExists(atPath: nosubPath.path) {
                    summaryStatus[video.bvid] = .noSubtitle
                } else {
                    summaryStatus[video.bvid] = .none
                }
            }
        } catch {
            errorMessage = "加载视频列表失败: \(error.localizedDescription)"
        }

        isLoadingVideos = false
    }

    // MARK: - Load More

    func loadMore(credential: BiliCredential) async {
        guard hasMore else { return }
        currentPage += 1
        await loadVideos(credential: credential)
    }

    // MARK: - Summarize Unsummarized

    func summarizeUnsummarized(credential: BiliCredential) async {
        // Also retry .noSubtitle videos (they may have been from a previous failed run)
        let unsummarized = videos.filter { summaryStatus[$0.bvid] == .none || summaryStatus[$0.bvid] == .noSubtitle }
        let bvids = unsummarized.map(\.bvid)
        let titles = Dictionary(uniqueKeysWithValues: unsummarized.map { ($0.bvid, $0.title) })

        guard !bvids.isEmpty else {
            errorMessage = "所有视频都已总结"
            return
        }

        // Mark as processing
        for bvid in bvids {
            summaryStatus[bvid] = .processing
        }

        await homeVM.processBatch(
            bvids: bvids,
            credential: credential,
            outputSubdir: Constants.favoritesSubdir,
            titles: titles
        )

        // Refresh status for all processed videos
        refreshStatusForVideos(bvids: bvids)
    }

    // MARK: - Summarize Selected

    func summarizeSelected(bvids: [String], credential: BiliCredential) async {
        // Build titles dict from known videos
        let titles = Dictionary(uniqueKeysWithValues: videos.filter { bvids.contains($0.bvid) }.map { ($0.bvid, $0.title) })
        for bvid in bvids {
            summaryStatus[bvid] = .processing
        }

        await homeVM.processBatch(
            bvids: bvids,
            credential: credential,
            outputSubdir: Constants.favoritesSubdir,
            titles: titles
        )

        // Refresh status for processed videos
        refreshStatusForVideos(bvids: bvids)
    }

    // MARK: - Refresh Status Helper

    private func refreshStatusForVideos(bvids: [String]) {
        for bvid in bvids {
            guard let video = videos.first(where: { $0.bvid == bvid }) else { continue }
            let safe = Summary.sanitizeFilename(video.title)
            let normalPath = storage.summaryRoot
                .appendingPathComponent(Constants.favoritesSubdir)
                .appendingPathComponent("\(safe).md")
            let nosubPath = storage.summaryRoot
                .appendingPathComponent(Constants.favoritesSubdir)
                .appendingPathComponent("no_subtitle/\(safe).md")

            if FileManager.default.fileExists(atPath: normalPath.path) {
                summaryStatus[bvid] = .done
            } else if FileManager.default.fileExists(atPath: nosubPath.path) {
                summaryStatus[bvid] = .noSubtitle
            } else {
                // Processing failed without saving any file
                summaryStatus[bvid] = .none
            }
        }
    }

    // MARK: - Unfavorite

    func unfavorite(bvid: String, credential: BiliCredential) async throws {
        guard let folder = selectedFolder else { return }
        try await biliAPI.unfavoriteVideo(bvid: bvid, folderId: folder.id, credential: credential)
        videos.removeAll { $0.bvid == bvid }
    }
}
