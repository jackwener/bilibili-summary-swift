import Foundation

// MARK: - Network Client

/// A thin HTTP client with B站 cookie support
final class NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            "Referer": "https://www.bilibili.com",
        ]
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String]? = nil,
        credential: BiliCredential? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        // Add credential cookies
        if let cred = credential {
            request.setValue(cred.cookieString, forHTTPHeaderField: "Cookie")
        }

        // Additional headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if method == "POST" && request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResp = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResp.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.httpError(statusCode: httpResp.statusCode, body: body)
        }

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Bilibili API Request (wrapped in BiliResponse)

    func biliRequest<T: Decodable>(
        path: String,
        params: [String: String] = [:],
        credential: BiliCredential? = nil
    ) async throws -> T {
        var components = URLComponents(string: Constants.bilibiliAPI + path)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        let response: BiliResponse<T> = try await request(url: url, credential: credential)

        guard response.code == 0 else {
            throw NetworkError.biliError(code: response.code, message: response.message)
        }

        guard let data = response.data else {
            throw NetworkError.noData
        }

        return data
    }

    // MARK: - Raw Data Download

    func downloadData(from url: URL, credential: BiliCredential? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        if let cred = credential {
            request.setValue(cred.cookieString, forHTTPHeaderField: "Cookie")
        }
        let (data, _) = try await session.data(for: request)
        return data
    }

    // MARK: - Download JSON

    func downloadJSON<T: Decodable>(from url: URL) async throws -> T {
        let data = try await downloadData(from: url)
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case httpError(statusCode: Int, body: String)
    case biliError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .invalidResponse: return "服务器返回无效"
        case .noData: return "未返回数据"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body.prefix(200))"
        case .biliError(let code, let message):
            return "B站 API 错误 (\(code)): \(message)"
        }
    }
}
