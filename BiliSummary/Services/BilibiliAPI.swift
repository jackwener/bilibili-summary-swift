import Foundation

// MARK: - Bilibili API Service

final class BilibiliAPI {
    static let shared = BilibiliAPI()

    private let client = NetworkClient.shared

    private init() {}

    // MARK: - Video Info

    /// Fetch video info by BV ID
    func getVideoInfo(bvid: String, credential: BiliCredential? = nil) async throws -> VideoInfo {
        try await client.biliRequest(
            path: "/x/web-interface/view",
            params: ["bvid": bvid],
            credential: credential
        )
    }

    // MARK: - Video Pages (分P)

    /// Fetch video page list to get cid
    func getVideoPages(bvid: String, credential: BiliCredential? = nil) async throws -> [VideoPage] {
        try await client.biliRequest(
            path: "/x/player/pagelist",
            params: ["bvid": bvid],
            credential: credential
        )
    }

    // MARK: - Player Info (subtitles)

    /// Fetch player info containing subtitle tracks
    func getPlayerInfo(bvid: String, cid: Int, credential: BiliCredential? = nil) async throws -> PlayerInfo {
        let info: PlayerInfo = try await client.biliRequest(
            path: "/x/player/v2",
            params: ["bvid": bvid, "cid": String(cid)],
            credential: credential
        )
        
        // Debug: log subtitle tracks
        if let subtitles = info.subtitle?.subtitles, let first = subtitles.first {
            print("🔍 [\(bvid)] Subtitle track: lan=\(first.lan), url=\(first.subtitleUrl ?? "<empty>")")
        }
        
        return info
    }

    // MARK: - User Info

    /// Fetch user profile info using the card API (more reliable, no WBI needed)
    func getUserInfo(uid: Int, credential: BiliCredential? = nil) async throws -> UserInfo {
        let data: UserCardData = try await client.biliRequest(
            path: "/x/web-interface/card",
            params: ["mid": String(uid)],
            credential: credential
        )
        return UserInfo(mid: data.card.mid, name: data.card.name, face: data.card.face, sign: data.card.sign)
    }

    /// Fetch self info (requires login)
    func getSelfInfo(credential: BiliCredential) async throws -> UserInfo {
        try await client.biliRequest(
            path: "/x/space/myinfo",
            credential: credential
        )
    }

    // MARK: - User Videos

    /// Fetch user's video list with WBI signing (required by B站)
    func getUserVideos(uid: Int, page: Int = 1, pageSize: Int = 50, credential: BiliCredential? = nil) async throws -> UserVideosData {
        let params: [String: String] = [
            "mid": String(uid),
            "ps": String(min(pageSize, 50)),
            "pn": String(page),
        ]
        
        // Sign params with WBI
        let signedParams = try await WBIService.shared.signParams(params, credential: credential)
        
        return try await client.biliRequest(
            path: "/x/space/wbi/arc/search",
            params: signedParams,
            credential: credential
        )
    }

    /// Fetch all BV IDs for a user up to `count`
    func getAllUserBVIDs(uid: Int, count: Int, credential: BiliCredential? = nil) async throws -> [String] {
        var bvids: [String] = []
        var page = 1

        while bvids.count < count {
            let data = try await getUserVideos(uid: uid, page: page, pageSize: min(count - bvids.count, 50), credential: credential)

            guard let vlist = data.list?.vlist, !vlist.isEmpty else { break }

            for v in vlist {
                bvids.append(v.bvid)
                if bvids.count >= count { break }
            }

            page += 1
            if page > 20 { break }  // safety limit
        }

        return bvids
    }

    // MARK: - Search User

    /// Search for users by name (returns full list)
    func searchUsers(name: String, credential: BiliCredential? = nil) async throws -> [SearchUserItem] {
        // Use the general search API with credential to avoid 412
        let data: SearchResultWrapper = try await client.biliRequest(
            path: "/x/web-interface/wbi/search/type",
            params: [
                "search_type": "bili_user",
                "keyword": name,
            ],
            credential: credential
        )
        return data.result ?? []
    }

    /// Search for a user by name using the search suggest API (no WBI needed)
    @available(*, deprecated, message: "Use searchUsers instead")
    func searchUser(name: String, credential: BiliCredential? = nil) async throws -> Int? {
        try await searchUsers(name: name, credential: credential).first?.mid
    }

    // MARK: - Favorites

    /// Get all favorite folders for a user
    func getFavoriteFolders(uid: Int, credential: BiliCredential) async throws -> [FavoriteFolder] {
        let data: FavoriteFolderListData = try await client.biliRequest(
            path: "/x/v3/fav/folder/created/list-all",
            params: ["up_mid": String(uid)],
            credential: credential
        )
        return data.list?.map(\.asFolder) ?? []
    }

    /// Get videos in a favorite folder
    func getFavoriteVideos(mediaId: Int, page: Int = 1, pageSize: Int = 20, credential: BiliCredential) async throws -> (videos: [FavoriteVideo], hasMore: Bool) {
        let data: FavoriteContentData = try await client.biliRequest(
            path: "/x/v3/fav/resource/list",
            params: [
                "media_id": String(mediaId),
                "pn": String(page),
                "ps": String(pageSize),
            ],
            credential: credential
        )
        let videos = data.medias?.map(\.asFavoriteVideo) ?? []
        return (videos, data.hasMore ?? false)
    }

    /// Get BV IDs from default favorite folder
    func getDefaultFavoriteBVIDs(count: Int, credential: BiliCredential) async throws -> [String] {
        let selfInfo = try await getSelfInfo(credential: credential)
        let folders = try await getFavoriteFolders(uid: selfInfo.mid, credential: credential)

        guard let defaultFolder = folders.first(where: \.isDefault) ?? folders.first else {
            return []
        }

        var bvids: [String] = []
        var page = 1

        while bvids.count < count {
            let (videos, hasMore) = try await getFavoriteVideos(mediaId: defaultFolder.id, page: page, credential: credential)

            for v in videos {
                bvids.append(v.bvid)
                if bvids.count >= count { break }
            }

            if !hasMore { break }
            page += 1
            if page > 10 { break }
        }

        return bvids
    }

    /// Unfavorite a video
    func unfavoriteVideo(bvid: String, folderId: Int, credential: BiliCredential) async throws {
        let info = try await getVideoInfo(bvid: bvid, credential: credential)
        let aid = info.aid

        var components = URLComponents(string: Constants.bilibiliAPI + "/x/v3/fav/resource/batch-del")!
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.cookieString, forHTTPHeaderField: "Cookie")

        let body = "resources=\(aid):2&media_id=\(folderId)&csrf=\(credential.biliJct)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(BiliResponse<EmptyData>.self, from: data)

        guard response.code == 0 else {
            throw NetworkError.biliError(code: response.code, message: response.message)
        }
    }
}

// MARK: - Empty Response Data

struct EmptyData: Codable {}
