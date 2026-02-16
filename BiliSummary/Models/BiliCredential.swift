import Foundation

// MARK: - Bilibili Credential

struct BiliCredential: Codable {
    let sessdata: String
    let biliJct: String
    let acTimeValue: String?

    var isValid: Bool {
        !sessdata.isEmpty
    }

    /// Cookie header value for API requests
    var cookieString: String {
        var cookies = "SESSDATA=\(sessdata); bili_jct=\(biliJct)"
        if let ac = acTimeValue, !ac.isEmpty {
            cookies += "; ac_time_value=\(ac)"
        }
        return cookies
    }
}
