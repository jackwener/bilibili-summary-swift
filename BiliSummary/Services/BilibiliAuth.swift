import Foundation
import WebKit

// MARK: - Bilibili Auth Service (WebView Login)

/// Handles Bilibili login via WKWebView.
/// The user logs in through B站's mobile web page, and we extract cookies afterwards.
@MainActor
final class BilibiliAuth: NSObject, ObservableObject {
    static let shared = BilibiliAuth()

    @Published var credential: BiliCredential?
    @Published var isLoggedIn = false
    @Published var userName: String = ""
    @Published var userAvatar: String = ""

    private override init() {
        super.init()
        // Load saved credential on init
        if let saved = AppPreferences.shared.loadCredential(), saved.isValid {
            self.credential = saved
            self.isLoggedIn = true
            // Fetch user info in background
            Task {
                await fetchUserInfo()
            }
        }
    }

    // MARK: - Login URL

    var loginURL: URL {
        URL(string: Constants.bilibiliLoginURL)!
    }

    // MARK: - Extract Credential from WebView Cookies

    func extractCredential(from webView: WKWebView) async -> Bool {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await cookieStore.allCookies()

        var sessdata: String?
        var biliJct: String?
        var acTimeValue: String?

        for cookie in cookies {
            switch cookie.name {
            case "SESSDATA":
                sessdata = cookie.value
            case "bili_jct":
                biliJct = cookie.value
            case "ac_time_value":
                acTimeValue = cookie.value
            default:
                break
            }
        }

        guard let sess = sessdata, !sess.isEmpty,
              let jct = biliJct, !jct.isEmpty else {
            return false
        }

        let cred = BiliCredential(
            sessdata: sess,
            biliJct: jct,
            acTimeValue: acTimeValue
        )

        // Save to preferences
        AppPreferences.shared.saveCredential(cred)

        self.credential = cred
        self.isLoggedIn = true

        // Fetch user info
        await fetchUserInfo()

        return true
    }

    // MARK: - Fetch User Info

    func fetchUserInfo() async {
        guard let cred = credential else { return }
        do {
            let info = try await BilibiliAPI.shared.getSelfInfo(credential: cred)
            self.userName = info.name
            let face = info.face
            self.userAvatar = face.hasPrefix("//") ? "https:\(face)" : face
        } catch {
            print("Failed to fetch user info: \(error)")
        }
    }

    // MARK: - Logout

    func logout() {
        credential = nil
        isLoggedIn = false
        userName = ""
        userAvatar = ""
        AppPreferences.shared.clearCredential()

        // Clear WebView cookies
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            for record in records where record.displayName.contains("bilibili") {
                dataStore.removeData(ofTypes: record.dataTypes, for: [record]) {}
            }
        }
    }

    // MARK: - Check if URL indicates login success

    func isLoginSuccessURL(_ url: URL) -> Bool {
        let urlStr = url.absoluteString
        return urlStr.contains("bilibili.com") &&
               !urlStr.contains("passport") &&
               !urlStr.contains("login")
    }
}
