import Foundation

// MARK: - User Summary ViewModel

@MainActor
final class UserSummaryViewModel: ObservableObject {
    @Published var userInput: String = ""
    @Published var videoCount: Int = 50
    @Published var resolvedName: String = ""
    @Published var resolvedUID: Int?
    @Published var isResolving = false
    @Published var isSearching = false
    @Published var searchSuggestions: [SearchUserItem] = []
    @Published var showSuggestions = false
    @Published var errorMessage: String?

    let homeVM: HomeViewModel

    private let biliAPI = BilibiliAPI.shared
    private var searchTask: Task<Void, Never>?

    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
    }

    // MARK: - Search Suggestions

    func updateSearchSuggestions(credential: BiliCredential? = nil) {
        let input = userInput.trimmingCharacters(in: .whitespaces)

        // Cancel previous search
        searchTask?.cancel()

        guard !input.isEmpty, input.count >= Constants.searchMinChars else {
            searchSuggestions = []
            showSuggestions = false
            return
        }

        // Don't search if it's a number (likely UID)
        if Int(input) != nil {
            searchSuggestions = []
            showSuggestions = false
            return
        }

        searchTask = Task {
            // Debounce: wait before searching
            try? await Task.sleep(for: .milliseconds(Constants.searchDebounceMs))

            guard !Task.isCancelled else { return }

            await performSearch(input: input, credential: credential)
        }
    }

    private func performSearch(input: String, credential: BiliCredential? = nil) async {
        isSearching = true
        defer { isSearching = false }

        do {
            let users = try await biliAPI.searchUsers(name: input, credential: credential)
            searchSuggestions = users
            showSuggestions = !users.isEmpty
        } catch {
            print("⚠️ Search failed: \(error)")
            searchSuggestions = []
            showSuggestions = false
        }
    }

    // MARK: - Select Suggestion

    func selectSuggestion(_ user: SearchUserItem, credential: BiliCredential? = nil) async {
        userInput = user.uname
        searchSuggestions = []
        showSuggestions = false
        resolvedUID = user.mid
        resolvedName = user.uname

        // Fetch full user info to get avatar etc.
        do {
            let info = try await biliAPI.getUserInfo(uid: user.mid, credential: credential)
            resolvedName = info.name
        } catch {
            // Ignore error, we already have the name from search
        }
    }

    // MARK: - Resolve User

    func resolveUser(credential: BiliCredential? = nil) async {
        let input = userInput.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }

        searchSuggestions = []
        showSuggestions = false
        isResolving = true
        errorMessage = nil

        do {
            if let uid = Int(input) {
                // Direct UID
                resolvedUID = uid
                let info = try await biliAPI.getUserInfo(uid: uid, credential: credential)
                resolvedName = info.name
            } else {
                // Search by name (pass credential to avoid HTTP 412)
                let users = try await biliAPI.searchUsers(name: input, credential: credential)
                guard let first = users.first else {
                    errorMessage = "未找到名为 \"\(input)\" 的 UP 主"
                    isResolving = false
                    return
                }
                resolvedUID = first.mid
                let info = try await biliAPI.getUserInfo(uid: first.mid, credential: credential)
                resolvedName = info.name
            }
        } catch {
            errorMessage = "查找 UP 主失败: \(error.localizedDescription)"
        }

        isResolving = false
    }

    // MARK: - Start Summarization

    func startSummarize(credential: BiliCredential?) async {
        guard let uid = resolvedUID else {
            errorMessage = "请先搜索 UP 主"
            return
        }

        errorMessage = nil

        do {
            // Save user meta
            StorageService.shared.saveUserMeta(uid: uid, name: resolvedName)

            // Fetch video list
            let bvids = try await biliAPI.getAllUserBVIDs(uid: uid, count: videoCount, credential: credential)

            guard !bvids.isEmpty else {
                errorMessage = "未找到视频"
                return
            }

            await homeVM.processBatch(
                bvids: bvids,
                credential: credential,
                outputSubdir: Constants.usersSubdir(uid)
            )
        } catch {
            errorMessage = "获取视频列表失败: \(error.localizedDescription)"
        }
    }
}
