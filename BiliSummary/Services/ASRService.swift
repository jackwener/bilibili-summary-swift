import Foundation
import AVFoundation

// MARK: - ASR Service (GLM ASR for videos without subtitles)

final class ASRService {
    static let shared = ASRService()

    private init() {}

    /// Segment duration for audio splits (seconds)
    private let segmentDuration: TimeInterval = 60

    // MARK: - Transcribe Video

    /// Download audio from B站 video, split into segments, transcribe via GLM ASR
    func transcribe(bvid: String, credential: BiliCredential?) async throws -> String {
        guard let baseURL = KeychainHelper.shared.apiBaseURL, !baseURL.isEmpty,
              let authToken = KeychainHelper.shared.apiAuthToken, !authToken.isEmpty else {
            throw AIError.notConfigured
        }

        // 1. Get video info and audio URL
        let pages = try await BilibiliAPI.shared.getVideoPages(bvid: bvid, credential: credential)
        guard let firstPage = pages.first else {
            throw ASRError.noPages
        }

        // Get audio stream URL
        let audioURL = try await getAudioURL(bvid: bvid, cid: firstPage.cid, credential: credential)

        // 2. Download audio
        var request = URLRequest(url: audioURL)
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        if let cred = credential {
            request.setValue(cred.cookieString, forHTTPHeaderField: "Cookie")
        }
        let (audioData, _) = try await URLSession.shared.data(for: request)

        // 3. Save to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let audioFile = tempDir.appendingPathComponent("\(bvid).m4a")
        try audioData.write(to: audioFile)
        defer { try? FileManager.default.removeItem(at: audioFile) }

        // 4. Split audio into segments and transcribe
        let asset = AVURLAsset(url: audioFile)
        let duration = try await asset.load(.duration).seconds

        var transcripts: [String] = []
        var offset: TimeInterval = 0

        while offset < duration {
            let segEnd = min(offset + segmentDuration, duration)
            let segmentFile = tempDir.appendingPathComponent("\(bvid)_seg\(Int(offset)).m4a")

            // Export segment
            try await exportSegment(from: asset, start: offset, end: segEnd, to: segmentFile)
            defer { try? FileManager.default.removeItem(at: segmentFile) }

            // Transcribe segment
            let segmentData = try Data(contentsOf: segmentFile)
            let text = try await transcribeSegment(audioData: segmentData, baseURL: baseURL, authToken: authToken)
            if !text.isEmpty {
                transcripts.append(text)
            }

            offset = segEnd
        }

        return transcripts.joined(separator: "\n")
    }

    // MARK: - Get Audio URL

    private func getAudioURL(bvid: String, cid: Int, credential: BiliCredential?) async throws -> URL {
        // Use the playurl API to get audio stream
        let params: [String: String] = [
            "bvid": bvid,
            "cid": String(cid),
            "fnval": "16",  // dash format
        ]

        var components = URLComponents(string: Constants.bilibiliAPI + "/x/player/playurl")!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        if let cred = credential {
            request.setValue(cred.cookieString, forHTTPHeaderField: "Cookie")
        }
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let dataDict = json?["data"] as? [String: Any],
              let dash = dataDict["dash"] as? [String: Any],
              let audioStreams = dash["audio"] as? [[String: Any]],
              let firstAudio = audioStreams.first,
              let baseUrl = firstAudio["baseUrl"] as? String ?? firstAudio["base_url"] as? String,
              let audioURL = URL(string: baseUrl) else {
            throw ASRError.noAudioStream
        }

        return audioURL
    }

    // MARK: - Export Audio Segment

    private func exportSegment(from asset: AVURLAsset, start: TimeInterval, end: TimeInterval, to outputURL: URL) async throws {
        let startTime = CMTime(seconds: start, preferredTimescale: 600)
        let endTime = CMTime(seconds: end, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ASRError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        await exportSession.export()

        if let error = exportSession.error {
            throw error
        }
    }

    // MARK: - Transcribe Single Segment

    private func transcribeSegment(audioData: Data, baseURL: String, authToken: String) async throws -> String {
        // Use GLM ASR API
        var asrURL = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        if asrURL.hasSuffix("/v1") {
            asrURL = String(asrURL.dropLast(3))
        }
        asrURL += "/v1/audio/transcriptions"

        guard let url = URL(string: asrURL) else {
            throw ASRError.invalidURL
        }

        // Build multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("asr\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse,
              (200...299).contains(httpResp.statusCode) else {
            throw ASRError.transcriptionFailed
        }

        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        return json?["text"] as? String ?? ""
    }
}

// MARK: - ASR Errors

enum ASRError: LocalizedError {
    case noPages
    case noAudioStream
    case exportFailed
    case invalidURL
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .noPages: return "无法获取视频分P信息"
        case .noAudioStream: return "无法获取音频流"
        case .exportFailed: return "音频导出失败"
        case .invalidURL: return "ASR API URL 无效"
        case .transcriptionFailed: return "语音识别失败"
        }
    }
}
