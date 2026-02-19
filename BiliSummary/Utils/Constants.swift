import Foundation

// MARK: - Constants

enum Constants {
    /// B站 API base
    static let bilibiliAPI = "https://api.bilibili.com"

    /// B站 Passport (login)
    static let bilibiliPassport = "https://passport.bilibili.com"

    /// B站 Mobile Login Page (for WebView login)
    static let bilibiliLoginURL = "https://passport.bilibili.com/h5-app/passport/login"

    /// B站 homepage (used to detect login success redirect)
    static let bilibiliHome = "https://m.bilibili.com"

    /// Default AI API base URL
    static let defaultAPIBaseURL = "https://open.bigmodel.cn/api/anthropic"

    /// Default AI model
    static let defaultModel = "GLM-4-FlashX-250414"

    /// Max subtitle characters sent to LLM
    static let maxSubtitleLength = 30_000

    /// Max concurrent video processing
    static let defaultConcurrency = 12

    /// AI API max tokens per request
    static let aiMaxTokens = 8192

    /// AI API max retries on rate limit
    static let aiMaxRetries = 5

    /// AI API base wait time for exponential backoff (seconds)
    static let aiRetryBaseWait: TimeInterval = 2

    /// AI API request timeout (seconds)
    static let aiRequestTimeout: TimeInterval = 120

    /// Delay between processing tasks (milliseconds)
    static let taskDelayMs: UInt64 = 200

    /// Search debounce delay (milliseconds)
    static let searchDebounceMs: UInt64 = 300

    /// Minimum characters to trigger search suggestions
    static let searchMinChars = 2

    /// Summary output directories
    static let standaloneSubdir = "standalone"
    static let favoritesSubdir = "favorites"

    static func usersSubdir(_ uid: Int) -> String {
        "users/\(uid)"
    }

    // MARK: - Keychain Keys

    enum Keychain {
        static let service = "com.jakevin.BiliSummary"
        static let sessdata = "bilibili_sessdata"
        static let biliJct = "bilibili_bili_jct"
        static let acTimeValue = "bilibili_ac_time_value"
        static let apiBaseURL = "ai_api_base_url"
        static let apiAuthToken = "ai_api_auth_token"
        static let aiModel = "ai_model"
    }

    // MARK: - UserDefaults Keys

    enum Defaults {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    // MARK: - LLM Prompt (identical to Python version)

    static let summarizePrompt = """
你是一个专业的视频内容分析师。请根据以下视频字幕，生成一份**全面、精细且有条理**的视频笔记。

视频标题: {title}

字幕内容:
{subtitle}

请用中文输出，严格按照以下格式：

## 内容整理

将作者的原始表述进行整理和精简，去除口语化的重复、语气词和冗余表达，但**不能遗漏任何实质内容**。用更清晰流畅的书面语重新组织，保留作者的原意、论证逻辑和关键用词。按话题分段呈现。

## 核心观点

全面覆盖作者在视频中表达的所有重要观点，不要人为限制数量。每个观点下面：
- 先用一句话精准概括该观点
- 然后列出作者用来支撑该观点的**具体例子、故事、数据或类比**（如果有的话）

注意：观点数量应由内容决定，确保不遗漏任何重要论点。短视频可能只有 2-3 个观点，长视频可能有 10 个以上。

## 行动建议

如果视频包含可操作的建议或方法论，请列出具体的行动步骤。如果视频偏向于分享观点/故事而非方法论，可以省略此部分。
"""
}
