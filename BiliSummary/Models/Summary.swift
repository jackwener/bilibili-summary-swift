import Foundation

// MARK: - Summary (stored locally)

struct Summary: Codable, Identifiable {
    let title: String
    let bvid: String
    let url: String
    let duration: Int
    let authorName: String
    let authorUID: Int
    let coverURL: String
    let generatedAt: String
    let category: String           // "standalone", "favorites", "users/{uid}"
    let hasSubtitle: Bool

    var id: String { bvid }

    /// Relative path for the summary markdown file
    var relativePath: String {
        let safe = Summary.sanitizeFilename(title)
        if hasSubtitle {
            return "\(category)/\(safe).md"
        } else {
            return "\(category)/no_subtitle/\(safe).md"
        }
    }

    var metaRelativePath: String {
        let safe = Summary.sanitizeFilename(title)
        if hasSubtitle {
            return "\(category)/\(safe).meta.json"
        } else {
            return "\(category)/no_subtitle/\(safe).meta.json"
        }
    }

    var videoCoverURL: URL? {
        let urlStr = coverURL.hasPrefix("//") ? "https:\(coverURL)" : coverURL
        return URL(string: urlStr)
    }

    var durationFormatted: String {
        let m = duration / 60
        let s = duration % 60
        return String(format: "%02d:%02d", m, s)
    }

    var videoURL: URL? {
        URL(string: "https://www.bilibili.com/video/\(bvid)")
    }

    // MARK: - Filename Sanitization

    static func sanitizeFilename(_ title: String) -> String {
        let illegal = CharacterSet(charactersIn: "<>:\"/\\|?*")
        return title.unicodeScalars
            .map { illegal.contains($0) ? "_" : String($0) }
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Summary Meta JSON (compatible with Python version)

struct SummaryMeta: Codable {
    let title: String
    let bvid: String
    let url: String
    let duration: Int
    let authorName: String
    let authorUID: Int
    let coverURL: String
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case title, bvid, url, duration
        case authorName = "author_name"
        case authorUID = "author_uid"
        case coverURL = "cover_url"
        case generatedAt = "generated_at"
    }
}
