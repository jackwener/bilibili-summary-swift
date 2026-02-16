import Foundation

// MARK: - Settings Storage (UserDefaults)

/// Manages storage of credentials and API settings using UserDefaults.
/// Note: Keychain requires code signing entitlements which complicates
/// simulator builds. For a personal tool, UserDefaults is sufficient
/// (same security level as Python version's .env.local file).
final class KeychainHelper {
    static let shared = KeychainHelper()

    private let defaults = UserDefaults.standard
    private let prefix = "com.jakevin.BiliSummary."

    private init() {}

    // MARK: - Bilibili Credential

    func saveCredential(_ credential: BiliCredential) {
        set(credential.sessdata, forKey: Constants.Keychain.sessdata)
        set(credential.biliJct, forKey: Constants.Keychain.biliJct)
        if let acTime = credential.acTimeValue {
            set(acTime, forKey: Constants.Keychain.acTimeValue)
        }
    }

    func loadCredential() -> BiliCredential? {
        guard let sess = get(forKey: Constants.Keychain.sessdata),
              let jct = get(forKey: Constants.Keychain.biliJct) else {
            return nil
        }
        let acTime = get(forKey: Constants.Keychain.acTimeValue)
        return BiliCredential(sessdata: sess, biliJct: jct, acTimeValue: acTime)
    }

    func clearCredential() {
        delete(forKey: Constants.Keychain.sessdata)
        delete(forKey: Constants.Keychain.biliJct)
        delete(forKey: Constants.Keychain.acTimeValue)
    }

    // MARK: - AI API Settings

    var apiBaseURL: String? {
        get { get(forKey: Constants.Keychain.apiBaseURL) }
        set {
            if let val = newValue { set(val, forKey: Constants.Keychain.apiBaseURL) }
            else { delete(forKey: Constants.Keychain.apiBaseURL) }
        }
    }

    var apiAuthToken: String? {
        get { get(forKey: Constants.Keychain.apiAuthToken) }
        set {
            if let val = newValue { set(val, forKey: Constants.Keychain.apiAuthToken) }
            else { delete(forKey: Constants.Keychain.apiAuthToken) }
        }
    }

    var aiModel: String {
        get { get(forKey: Constants.Keychain.aiModel) ?? Constants.defaultModel }
        set { set(newValue, forKey: Constants.Keychain.aiModel) }
    }

    var maskedAuthToken: String {
        guard let token = apiAuthToken, token.count > 8 else { return "" }
        return String(token.prefix(4)) + "****" + String(token.suffix(4))
    }

    // MARK: - UserDefaults Operations

    private func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: prefix + key)
    }

    private func get(forKey key: String) -> String? {
        defaults.string(forKey: prefix + key)
    }

    private func delete(forKey key: String) {
        defaults.removeObject(forKey: prefix + key)
    }
}
