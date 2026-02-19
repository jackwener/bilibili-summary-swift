import Foundation

// MARK: - AI Service (Anthropic-compatible)

final class AIService {
    static let shared = AIService()

    private init() {}

    // MARK: - Summarize

    /// Generate summary using LLM, returns (summary_text, duration_seconds)
    func summarize(subtitle: String, title: String) async throws -> (text: String, duration: TimeInterval) {
        guard !subtitle.isEmpty else {
            return ("⚠️ 无法获取字幕，无法生成总结", 0)
        }

        guard let baseURL = AppPreferences.shared.apiBaseURL, !baseURL.isEmpty,
              let authToken = AppPreferences.shared.apiAuthToken, !authToken.isEmpty else {
            throw AIError.notConfigured
        }

        let model = AppPreferences.shared.aiModel

        // Build prompt
        let prompt = summarizePrompt
            .replacingOccurrences(of: "{title}", with: title)
            .replacingOccurrences(of: "{subtitle}", with: subtitle.truncated(to: Constants.maxSubtitleLength))

        // Build request
        let urlString = baseURL.hasSuffix("/") ? "\(baseURL)v1/messages" : "\(baseURL)/v1/messages"
        guard let url = URL(string: urlString) else {
            throw AIError.invalidURL
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": Constants.aiMaxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        // Retry logic
        let maxRetries = Constants.aiMaxRetries
        let baseWait: TimeInterval = Constants.aiRetryBaseWait

        for attempt in 0..<maxRetries {
            do {
                let startTime = Date()
                let result = try await makeRequest(url: url, body: jsonData, authToken: authToken)
                let duration = Date().timeIntervalSince(startTime)
                return (result, duration)
            } catch AIError.rateLimited {
                if attempt < maxRetries - 1 {
                    let waitTime = baseWait * pow(2, Double(attempt))
                    print("  ⚠️ Rate limited, waiting \(waitTime)s...")
                    try await Task.sleep(for: .seconds(waitTime))
                } else {
                    throw AIError.rateLimitExhausted
                }
            }
        }

        throw AIError.unknown
    }

    // MARK: - HTTP Request

    private func makeRequest(url: URL, body: Data, authToken: String) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(authToken, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = Constants.aiRequestTimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResp.statusCode == 429 {
            throw AIError.rateLimited
        }

        guard (200...299).contains(httpResp.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIError.httpError(statusCode: httpResp.statusCode, body: body)
        }

        // Parse Anthropic response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw AIError.invalidResponseFormat
        }

        return text
    }

    // MARK: - List Models

    func listModels() async throws -> [AIModel] {
        guard let baseURL = AppPreferences.shared.apiBaseURL, !baseURL.isEmpty,
              let authToken = AppPreferences.shared.apiAuthToken, !authToken.isEmpty else {
            throw AIError.notConfigured
        }

        let trimmedBase = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))

        // Try multiple discovery patterns
        let candidateURLs: [String] = [
            // If base ends with /v1, try /v1/models
            trimmedBase.hasSuffix("/v1") ? "\(trimmedBase)/models" : nil,
            // Standard OpenAI-compatible: base + /v1/models
            "\(trimmedBase)/v1/models",
            // Direct: base + /models (some providers)
            "\(trimmedBase)/models",
        ].compactMap { $0 }

        for urlString in candidateURLs {
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue(authToken, forHTTPHeaderField: "x-api-key")
            request.timeoutInterval = 10

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResp = response as? HTTPURLResponse else { continue }

                if httpResp.statusCode == 404 || httpResp.statusCode == 405 {
                    continue // Try next URL
                }

                guard (200...299).contains(httpResp.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    print("⚠️ Models API \(urlString) returned \(httpResp.statusCode): \(body.prefix(200))")
                    throw AIError.httpError(statusCode: httpResp.statusCode, body: body)
                }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let modelsArray = json?["data"] as? [[String: Any]] ?? []

                let models = modelsArray.compactMap { dict in
                    guard let id = dict["id"] as? String else { return nil as AIModel? }
                    return AIModel(id: id, ownedBy: dict["owned_by"] as? String ?? "")
                }.sorted { $0.id < $1.id }

                if !models.isEmpty {
                    print("✅ Found \(models.count) models from \(urlString)")
                    return models
                }
            } catch {
                if error is AIError { throw error }
                continue // Try next URL
            }
        }

        // No models found from any endpoint
        return []
    }
}

// MARK: - AI Model

struct AIModel: Identifiable {
    let id: String
    let ownedBy: String
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case invalidResponseFormat
    case rateLimited
    case rateLimitExhausted
    case httpError(statusCode: Int, body: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI API 未配置，请在设置中配置"
        case .invalidURL: return "无效的 API URL"
        case .invalidResponse: return "无效的 API 响应"
        case .invalidResponseFormat: return "API 响应格式错误"
        case .rateLimited: return "API 速率限制"
        case .rateLimitExhausted: return "API 速率限制，重试次数已耗尽"
        case .httpError(let code, let body): return "API 错误 (\(code)): \(body.prefix(200))"
        case .unknown: return "未知 API 错误"
        }
    }
}
