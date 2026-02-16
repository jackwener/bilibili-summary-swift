import Foundation

// MARK: - URL Summary ViewModel

@MainActor
final class URLSummaryViewModel: ObservableObject {
    @Published var urlText: String = ""
    @Published var parsedBVIDs: [String] = []
    @Published var validationMessage: String = ""

    let homeVM: HomeViewModel

    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
    }

    // MARK: - Parse URLs

    func parseURLs() {
        let lines = urlText.components(separatedBy: .newlines)
        var bvids: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if let bvid = trimmed.extractBVID() {
                if !bvids.contains(bvid) {
                    bvids.append(bvid)
                }
            }
        }

        parsedBVIDs = bvids

        if bvids.isEmpty && !urlText.isEmpty {
            validationMessage = "未找到有效的 BV 号"
        } else if !bvids.isEmpty {
            validationMessage = "找到 \(bvids.count) 个视频"
        } else {
            validationMessage = ""
        }
    }

    // MARK: - Start Summarization

    func startSummarize(credential: BiliCredential?) async {
        guard !parsedBVIDs.isEmpty else { return }
        await homeVM.processBatch(
            bvids: parsedBVIDs,
            credential: credential,
            outputSubdir: Constants.standaloneSubdir
        )
    }
}
