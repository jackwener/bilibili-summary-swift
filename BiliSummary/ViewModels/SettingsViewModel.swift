import Foundation

// MARK: - Settings ViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var baseURL: String = ""
    @Published var authToken: String = ""
    @Published var selectedModel: String = ""
    @Published var availableModels: [AIModel] = []
    @Published var isLoadingModels = false
    @Published var isSaving = false
    @Published var saveMessage: String?
    @Published var errorMessage: String?

    private let keychain = KeychainHelper.shared
    private let aiService = AIService.shared

    // MARK: - Load Settings

    func loadSettings() {
        baseURL = keychain.apiBaseURL ?? Constants.defaultAPIBaseURL
        authToken = keychain.apiAuthToken ?? ""
        selectedModel = keychain.aiModel
    }

    // MARK: - Save Settings

    func saveSettings() {
        isSaving = true
        saveMessage = nil
        errorMessage = nil

        keychain.apiBaseURL = baseURL.isEmpty ? nil : baseURL
        keychain.apiAuthToken = authToken.isEmpty ? nil : authToken
        if !selectedModel.isEmpty {
            keychain.aiModel = selectedModel
        }

        // Verify save by reading back
        let savedURL = keychain.apiBaseURL ?? "<nil>"
        let savedToken = keychain.apiAuthToken != nil ? "✅ saved (\(keychain.maskedAuthToken))" : "❌ nil"
        print("💾 Settings saved — URL: \(savedURL), Token: \(savedToken), Model: \(keychain.aiModel)")

        isSaving = false
        saveMessage = "设置已保存"

        // Clear message after delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            saveMessage = nil
        }
    }

    // MARK: - Load Models

    func loadModels() async {
        // Auto-save current settings first so Keychain has the latest values
        saveSettings()

        isLoadingModels = true
        errorMessage = nil

        do {
            availableModels = try await aiService.listModels()
            if availableModels.isEmpty {
                errorMessage = "未找到可用模型（API 可能不支持模型列表）"
            }
        } catch {
            errorMessage = "加载模型列表失败: \(error.localizedDescription)"
        }

        isLoadingModels = false
    }

    // MARK: - Validation

    var isConfigured: Bool {
        !baseURL.isEmpty && !authToken.isEmpty
    }

    var maskedToken: String {
        keychain.maskedAuthToken
    }
}
