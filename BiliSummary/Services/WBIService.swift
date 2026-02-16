import Foundation
import CryptoKit

// MARK: - WBI Signing Service

/// Handles WBI signature generation for Bilibili API requests
final class WBIService {
    static let shared = WBIService()

    private let client = NetworkClient.shared

    /// Cached mixin key (valid for a few hours)
    private var cachedMixinKey: String?
    private var cacheTime: Date?
    private let cacheDuration: TimeInterval = 3600 // 1 hour

    /// Predefined index table for generating mixin key
    private let mixinKeyEncTab: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
        37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
        22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
    ]

    /// Characters to filter from parameter values
    private let filterChars = CharacterSet(charactersIn: "!'()*")

    private init() {}

    // MARK: - Sign Parameters

    /// Add WBI signature (w_rid and wts) to the given parameters
    func signParams(_ params: [String: String], credential: BiliCredential? = nil) async throws -> [String: String] {
        let mixinKey = try await getMixinKey(credential: credential)

        var signedParams = params
        let wts = String(Int(Date().timeIntervalSince1970))
        signedParams["wts"] = wts

        // Sort by key
        let sorted = signedParams.sorted { $0.key < $1.key }

        // Build query string (filter special chars from values)
        let queryString = sorted.map { key, value in
            let filteredValue = value.unicodeScalars
                .filter { !filterChars.contains($0) }
                .map { String($0) }
                .joined()
            return "\(key)=\(filteredValue)"
        }.joined(separator: "&")

        // MD5 hash of query + mixinKey
        let toHash = queryString + mixinKey
        let digest = Insecure.MD5.hash(data: Data(toHash.utf8))
        let wRid = digest.map { String(format: "%02x", $0) }.joined()

        signedParams["w_rid"] = wRid
        return signedParams
    }

    // MARK: - Get Mixin Key

    private func getMixinKey(credential: BiliCredential? = nil) async throws -> String {
        // Return cached key if still valid
        if let key = cachedMixinKey, let time = cacheTime,
           Date().timeIntervalSince(time) < cacheDuration {
            return key
        }

        // Fetch nav data to get img_url and sub_url
        let navData: NavData = try await client.biliRequest(
            path: "/x/web-interface/nav",
            credential: credential
        )

        guard let imgURL = navData.wbiImg?.imgUrl,
              let subURL = navData.wbiImg?.subUrl else {
            throw WBIError.missingKeys
        }

        // Extract key from URL: take filename without extension
        let imgKey = extractKey(from: imgURL)
        let subKey = extractKey(from: subURL)

        let combined = imgKey + subKey

        // Apply mixin table
        let mixinKey = String(mixinKeyEncTab.prefix(32).map { index in
            let i = combined.index(combined.startIndex, offsetBy: index)
            return combined[i]
        })

        cachedMixinKey = mixinKey
        cacheTime = Date()

        return mixinKey
    }

    /// Extract key from URL like "https://.../{key}.png" -> "{key}"
    private func extractKey(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "" }
        return url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - Nav Data Model

struct NavData: Decodable {
    let wbiImg: WbiImgInfo?

    enum CodingKeys: String, CodingKey {
        case wbiImg = "wbi_img"
    }
}

struct WbiImgInfo: Decodable {
    let imgUrl: String?
    let subUrl: String?

    enum CodingKeys: String, CodingKey {
        case imgUrl = "img_url"
        case subUrl = "sub_url"
    }
}

// MARK: - WBI Error

enum WBIError: LocalizedError {
    case missingKeys

    var errorDescription: String? {
        switch self {
        case .missingKeys: return "获取 WBI 签名密钥失败"
        }
    }
}
