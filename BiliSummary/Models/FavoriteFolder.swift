import Foundation

// MARK: - Favorite Folder

struct FavoriteFolder: Codable, Identifiable {
    let id: Int
    let title: String
    let mediaCount: Int
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, title
        case mediaCount = "media_count"
        case isDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.mediaCount = try container.decodeIfPresent(Int.self, forKey: .mediaCount) ?? 0
        // attr == 0 means default folder in B站 API
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }

    init(id: Int, title: String, mediaCount: Int, isDefault: Bool) {
        self.id = id
        self.title = title
        self.mediaCount = mediaCount
        self.isDefault = isDefault
    }
}

// MARK: - Favorite Folder List Response

struct FavoriteFolderListData: Codable {
    let list: [FavoriteFolderRaw]?
}

struct FavoriteFolderRaw: Codable {
    let id: Int
    let title: String
    let mediaCount: Int?
    let attr: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, attr
        case mediaCount = "media_count"
    }

    var asFolder: FavoriteFolder {
        FavoriteFolder(
            id: id,
            title: title,
            mediaCount: mediaCount ?? 0,
            isDefault: attr == 0
        )
    }
}

// MARK: - Favorite Video

struct FavoriteVideo: Codable, Identifiable {
    let bvid: String
    let title: String
    let cover: String
    let duration: Int
    let upperName: String
    let upperMid: Int
    let playCount: Int

    var id: String { bvid }

    var coverURL: URL? {
        let urlStr = cover.hasPrefix("//") ? "https:\(cover)" : cover
        return URL(string: urlStr)
    }

    var durationFormatted: String {
        let m = duration / 60
        let s = duration % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Favorite Content Response

struct FavoriteContentData: Codable {
    let medias: [FavoriteMediaItem]?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case medias
        case hasMore = "has_more"
    }
}

struct FavoriteMediaItem: Codable {
    let bvid: String?
    let title: String?
    let cover: String?
    let duration: Int?
    let upper: FavoriteUpper?
    let cntInfo: FavoriteCntInfo?

    enum CodingKeys: String, CodingKey {
        case bvid, title, cover, duration, upper
        case cntInfo = "cnt_info"
    }

    var asFavoriteVideo: FavoriteVideo {
        let coverStr = cover ?? ""
        return FavoriteVideo(
            bvid: bvid ?? "",
            title: title ?? "",
            cover: coverStr.hasPrefix("//") ? "https:\(coverStr)" : coverStr,
            duration: duration ?? 0,
            upperName: upper?.name ?? "",
            upperMid: upper?.mid ?? 0,
            playCount: cntInfo?.play ?? 0
        )
    }
}

struct FavoriteUpper: Codable {
    let mid: Int?
    let name: String?
}

struct FavoriteCntInfo: Codable {
    let play: Int?
}
