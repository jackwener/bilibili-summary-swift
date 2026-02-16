import Foundation

// MARK: - Home ViewModel

/// Orchestrates the core video processing pipeline
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var progressItems: [ProgressItem] = []
    @Published var totalCount = 0
    @Published var completedCount = 0
    @Published var errorMessage: String?

    private let biliAPI = BilibiliAPI.shared
    private let subtitleService = SubtitleService.shared
    private let aiService = AIService.shared
    private let asrService = ASRService.shared
    private let storage = StorageService.shared

    struct ProgressItem: Identifiable {
        let id = UUID()
        let bvid: String
        var title: String
        var status: Status
        var message: String = ""

        enum Status {
            case pending, processing, success, skipped, failed, noSubtitle
        }
    }

    // MARK: - Process Single Video

    func processVideo(bvid: String, credential: BiliCredential?, outputSubdir: String) async {
        let url = "https://www.bilibili.com/video/\(bvid)"
        print("🚀 [\(bvid)] Starting processVideo")

        do {
            // 1. Get video info
            let info = try await biliAPI.getVideoInfo(bvid: bvid, credential: credential)
            print("📋 [\(bvid)] Title: \(info.title)")
            updateProgress(bvid: bvid, title: info.title, status: .processing, message: "获取字幕...")

            // 2. Check if already exists
            if storage.summaryExists(title: info.title, outputSubdir: outputSubdir) {
                print("⏭️ [\(bvid)] Already exists, skipping")
                updateProgress(bvid: bvid, title: info.title, status: .skipped, message: "已存在")
                completedCount += 1
                return
            }

            // 3. Get subtitles
            let (subtitleText, subtitleRaw) = try await subtitleService.getSubtitle(bvid: bvid, credential: credential)

            // 4. Save ASS
            if !subtitleRaw.isEmpty {
                try storage.saveASS(title: info.title, subtitles: subtitleRaw, outputSubdir: outputSubdir)
            }

            // 5. Determine if we have subtitle
            var finalText = subtitleText
            var hasSubtitle = !subtitleText.isEmpty

            if subtitleText.isEmpty {
                // Try ASR fallback
                updateProgress(bvid: bvid, title: info.title, status: .processing, message: "无字幕，尝试 ASR...")
                do {
                    finalText = try await asrService.transcribe(bvid: bvid, credential: credential)
                    hasSubtitle = false  // Mark as ASR-sourced
                } catch {
                    // Save with no subtitle flag
                    try storage.saveSummary(
                        title: info.title, bvid: bvid, url: url,
                        duration: info.duration, summary: "⚠️ 无法获取字幕，也无法进行语音识别",
                        outputSubdir: outputSubdir,
                        authorName: info.owner.name, authorUID: info.owner.mid,
                        coverURL: info.pic, hasSubtitle: false
                    )
                    updateProgress(bvid: bvid, title: info.title, status: .noSubtitle, message: "无字幕")
                    completedCount += 1
                    return
                }
            }

            // 6. Generate summary
            print("🤖 [\(bvid)] Starting AI summarization (text length: \(finalText.count))")
            updateProgress(bvid: bvid, title: info.title, status: .processing, message: "AI 总结中...")
            let (summary, duration) = try await aiService.summarize(subtitle: finalText, title: info.title)
            print("✅ [\(bvid)] AI summary complete (\(String(format: "%.1f", duration))s)")

            // 7. Save
            try storage.saveSummary(
                title: info.title, bvid: bvid, url: url,
                duration: info.duration, summary: summary,
                outputSubdir: outputSubdir,
                authorName: info.owner.name, authorUID: info.owner.mid,
                coverURL: info.pic, hasSubtitle: hasSubtitle
            )

            let durationStr = String(format: "%.1fs", duration)
            updateProgress(bvid: bvid, title: info.title, status: .success, message: "完成 (\(durationStr))")

        } catch {
            print("❌ [\(bvid)] processVideo FAILED: \(error.localizedDescription)")
            updateProgress(bvid: bvid, title: bvid, status: .failed, message: error.localizedDescription)
        }

        completedCount += 1
    }

    // MARK: - Batch Process

    /// Pending bvids queue — new requests are appended while processing is active
    private var pendingQueue: [(bvid: String, credential: BiliCredential?, outputSubdir: String)] = []
    private var isBatchRunning = false

    func processBatch(bvids: [String], credential: BiliCredential?, outputSubdir: String, concurrency: Int = Constants.defaultConcurrency) async {
        // Append new items to queue and progress list
        let newItems = bvids.map { ProgressItem(bvid: $0, title: $0, status: .pending) }
        progressItems.append(contentsOf: newItems)
        totalCount += bvids.count
        isProcessing = true
        errorMessage = nil

        for bvid in bvids {
            pendingQueue.append((bvid: bvid, credential: credential, outputSubdir: outputSubdir))
        }

        // If already running a batch loop, just return — the loop will pick up new items
        guard !isBatchRunning else { return }
        isBatchRunning = true

        await withTaskGroup(of: Void.self) { group in
            var running = 0

            while !pendingQueue.isEmpty {
                let item = pendingQueue.removeFirst()

                if running >= concurrency {
                    await group.next()
                    running -= 1
                }

                group.addTask {
                    await self.processVideo(bvid: item.bvid, credential: item.credential, outputSubdir: item.outputSubdir)
                    try? await Task.sleep(for: .milliseconds(500))
                }

                running += 1
            }

            await group.waitForAll()
        }

        isBatchRunning = false
        isProcessing = false
    }

    // MARK: - Progress Update

    private func updateProgress(bvid: String, title: String, status: ProgressItem.Status, message: String) {
        if let index = progressItems.firstIndex(where: { $0.bvid == bvid }) {
            progressItems[index].title = title
            progressItems[index].status = status
            progressItems[index].message = message
        }
    }

    func reset() {
        isProcessing = false
        isBatchRunning = false
        pendingQueue = []
        progressItems = []
        totalCount = 0
        completedCount = 0
        errorMessage = nil
    }
}
