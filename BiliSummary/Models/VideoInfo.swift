import Foundation

// MARK: - Bilibili API Response Wrapper

struct BiliResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

// MARK: - Video Info

struct VideoInfo: Codable, Identifiable {
    let bvid: String
    let aid: Int
    let title: String
    let duration: Int
    let pic: String       // cover URL
    let owner: VideoOwner
    let desc: String

    var id: String { bvid }

    var coverURL: URL? {
        let urlString = pic.hasPrefix("//") ? "https:\(pic)" : pic
        return URL(string: urlString)
    }

    var durationFormatted: String {
        let m = duration / 60
        let s = duration % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct VideoOwner: Codable {
    let mid: Int
    let name: String
    let face: String  // avatar URL
}

// MARK: - Video Page (分P)

struct VideoPage: Codable {
    let cid: Int
    let page: Int
    let part: String   // title of this page
    let duration: Int
}

// MARK: - Player Info (for subtitles)

struct PlayerInfo: Decodable {
    let subtitle: SubtitleInfo?
}

struct SubtitleInfo: Decodable {
    let subtitles: [SubtitleTrack]?
}

struct SubtitleTrack: Decodable {
    let lan: String          // language code, e.g. "zh-CN", "ai-zh"
    let lanDoc: String?      // display name
    let subtitleUrl: String? // URL to subtitle JSON

    enum CodingKeys: String, CodingKey {
        case lan
        case lanDoc = "lan_doc"
        case subtitleUrl = "subtitle_url"
    }

    var fullURL: URL? {
        guard let urlStr = subtitleUrl, !urlStr.isEmpty else { return nil }
        let full = urlStr.hasPrefix("//") ? "https:\(urlStr)" : urlStr
        return URL(string: full)
    }
}

// MARK: - User Videos Search Result

struct UserVideosData: Codable {
    let list: UserVideoList?

    struct UserVideoList: Codable {
        let vlist: [UserVideoItem]?
    }
}

struct UserVideoItem: Codable, Identifiable {
    let bvid: String
    let title: String
    let pic: String      // cover URL (often starts with //)
    let length: String   // "MM:SS"
    let author: String
    let mid: Int

    var id: String { bvid }

    var coverURL: URL? {
        let urlString = pic.hasPrefix("//") ? "https:\(pic)" : pic
        return URL(string: urlString)
    }
}

// MARK: - User Info

struct UserInfo: Decodable {
    let mid: Int
    let name: String
    let face: String
    let sign: String?

    init(mid: Int, name: String, face: String, sign: String?) {
        self.mid = mid
        self.name = name
        self.face = face
        self.sign = sign
    }
}

// MARK: - User Card Response (for /x/web-interface/card)

struct UserCardData: Decodable {
    let card: UserCardInfo
}

struct UserCardInfo: Decodable {
    let mid: Int
    let name: String
    let face: String
    let sign: String?

    enum CodingKeys: String, CodingKey {
        case mid, name, face, sign
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // mid can come as Int or String from different endpoints
        if let midInt = try? container.decode(Int.self, forKey: .mid) {
            self.mid = midInt
        } else if let midStr = try? container.decode(String.self, forKey: .mid),
                  let midInt = Int(midStr) {
            self.mid = midInt
        } else {
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: [CodingKeys.mid], debugDescription: "Cannot decode mid"))
        }
        self.name = try container.decode(String.self, forKey: .name)
        self.face = try container.decode(String.self, forKey: .face)
        self.sign = try container.decodeIfPresent(String.self, forKey: .sign)
    }
}

// MARK: - Search Result

struct SearchResultWrapper: Decodable {
    let result: [SearchUserItem]?
}

struct SearchUserItem: Decodable, Identifiable {
    let mid: Int
    let uname: String
    let usign: String?
    let upic: String?
    let fans: Int?
    let videos: Int?

    var id: Int { mid }

    enum CodingKeys: String, CodingKey {
        case mid, uname, usign, upic, fans, videos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // mid can come as Int or String in search results
        if let midInt = try? container.decode(Int.self, forKey: .mid) {
            self.mid = midInt
        } else if let midStr = try? container.decode(String.self, forKey: .mid),
                  let midInt = Int(midStr) {
            self.mid = midInt
        } else {
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: [CodingKeys.mid], debugDescription: "Cannot decode mid"))
        }
        self.uname = try container.decode(String.self, forKey: .uname)
        self.usign = try container.decodeIfPresent(String.self, forKey: .usign)
        self.upic = try container.decodeIfPresent(String.self, forKey: .upic)
        self.fans = try container.decodeIfPresent(Int.self, forKey: .fans)
        self.videos = try container.decodeIfPresent(Int.self, forKey: .videos)
    }

    var avatarURL: URL? {
        guard let upic = upic, !upic.isEmpty else { return nil }
        let urlStr = upic.hasPrefix("//") ? "https:\(upic)" : upic
        return URL(string: urlStr)
    }
}
