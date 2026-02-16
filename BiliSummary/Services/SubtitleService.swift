import Foundation

// MARK: - Subtitle Service

final class SubtitleService {
    static let shared = SubtitleService()

    private let api = BilibiliAPI.shared
    private let client = NetworkClient.shared

    private init() {}

    // MARK: - Get Subtitle Text + Raw Data

    /// Maximum retries when subtitle URL is empty (AI subtitles need warm-up)
    private let maxRetries = 3
    private let retryDelay: UInt64 = 2_000_000_000  // 2 seconds in nanoseconds

    /// Fetch subtitles for a video, returns (plainText, rawItems)
    func getSubtitle(bvid: String, credential: BiliCredential?) async throws -> (text: String, items: [SubtitleItem]) {
        // 1. Get cid from pages
        let pages = try await api.getVideoPages(bvid: bvid, credential: credential)
        guard let firstPage = pages.first else {
            print("⚠️ [\(bvid)] No pages found")
            return ("", [])
        }

        // 2. Get player info with subtitle tracks (with retry for empty subtitle_url)
        var subtitleURL: URL?
        var selectedLan = ""
        var hasTracksButNoURL = false

        for attempt in 1...maxRetries {
            let playerInfo = try await api.getPlayerInfo(bvid: bvid, cid: firstPage.cid, credential: credential)

            guard let subtitles = playerInfo.subtitle?.subtitles, !subtitles.isEmpty else {
                print("⚠️ [\(bvid)] No subtitle tracks found (credential: \(credential != nil ? "yes" : "no"))")
                return ("", [])
            }

            if attempt == 1 {
                print("✅ [\(bvid)] Found \(subtitles.count) subtitle tracks: \(subtitles.map { "\($0.lan)(\($0.lanDoc ?? "?"))" }.joined(separator: ", "))")
            }

            // Pick best subtitle track (prefer Chinese)
            var selectedTrack: SubtitleTrack?
            for track in subtitles {
                if track.lan.lowercased().contains("zh") {
                    selectedTrack = track
                    break
                }
            }
            if selectedTrack == nil {
                selectedTrack = subtitles.first
            }

            if let track = selectedTrack, let url = track.fullURL {
                subtitleURL = url
                selectedLan = track.lan
                break
            }

            // subtitle_url is empty — common for AI subtitles that need warm-up
            hasTracksButNoURL = true
            if attempt < maxRetries {
                print("🔄 [\(bvid)] subtitle_url is empty, retrying in 2s... (attempt \(attempt)/\(maxRetries))")
                try? await Task.sleep(nanoseconds: retryDelay)
            }
        }

        guard let url = subtitleURL else {
            if hasTracksButNoURL {
                print("⚠️ [\(bvid)] subtitle_url still empty after \(maxRetries) retries (AI subtitle not ready)")
            } else {
                print("⚠️ [\(bvid)] Could not get subtitle URL")
            }
            return ("", [])
        }

        print("📥 [\(bvid)] Downloading subtitle: \(selectedLan) from \(url)")

        // 3. Download subtitle JSON
        let body: SubtitleBody = try await client.downloadJSON(from: url)

        guard let items = body.body, !items.isEmpty else {
            print("⚠️ [\(bvid)] Subtitle body empty")
            return ("", [])
        }

        // 4. Extract plain text
        let text = items.map(\.content).joined(separator: "\n")

        print("✅ [\(bvid)] Got subtitle: \(items.count) items, \(text.count) chars")
        return (text, items)
    }
}
