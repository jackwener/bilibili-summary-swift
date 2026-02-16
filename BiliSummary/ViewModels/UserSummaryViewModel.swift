import Foundation

// MARK: - User Summary ViewModel

@MainActor
final class UserSummaryViewModel: ObservableObject {
    @Published var userInput: String = ""
    @Published var videoCount: Int = 50
    @Published var resolvedName: String = ""
    @Published var resolvedUID: Int?
    @Published var isResolving = false
    @Published var errorMessage: String?

    let homeVM: HomeViewModel

    private let biliAPI = BilibiliAPI.shared

    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
    }

    // MARK: - Resolve User

    func resolveUser(credential: BiliCredential? = nil) async {
        let input = userInput.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }

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
                guard let uid = try await biliAPI.searchUser(name: input, credential: credential) else {
                    errorMessage = "未找到名为 \"\(input)\" 的 UP 主"
                    isResolving = false
                    return
                }
                resolvedUID = uid
                let info = try await biliAPI.getUserInfo(uid: uid, credential: credential)
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
