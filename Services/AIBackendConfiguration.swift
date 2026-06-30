import Foundation

enum AIBackendProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case claude = "Claude"
    case gemini = "Gemini"
    case localMock = "Local Mock"

    var id: String { rawValue }

    var reviewPath: String {
        switch self {
        case .openAI:
            return "ai/openai/trade-review"
        case .claude:
            return "ai/claude/trade-review"
        case .gemini:
            return "ai/gemini/trade-review"
        case .localMock:
            return "ai/trade-review"
        }
    }

    var chartAnalysisPath: String {
        switch self {
        case .openAI:
            return "ai/openai/chart-analysis"
        case .claude:
            return "ai/claude/chart-analysis"
        case .gemini:
            return "ai/gemini/chart-analysis"
        case .localMock:
            return "ai/chart-analysis"
        }
    }
}

struct AIBackendConfiguration {
    let provider: AIBackendProvider
    let baseURL: URL?
    let bearerToken: String?
    let timeout: TimeInterval
    let retryCount: Int

    var isConfigured: Bool {
        provider != .localMock && baseURL != nil
    }

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> AIBackendConfiguration {
        let bundle = Bundle.main
        let providerValue = environment["AI_BACKEND_PROVIDER"]
            ?? bundle.object(forInfoDictionaryKey: "AI_BACKEND_PROVIDER") as? String
        let provider = AIBackendProvider(rawValue: providerValue ?? "") ?? .localMock

        let baseValue = environment["AI_BACKEND_BASE_URL"]
            ?? bundle.object(forInfoDictionaryKey: "AI_BACKEND_BASE_URL") as? String
        let trimmedBase = baseValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = trimmedBase.flatMap { $0.isEmpty ? nil : URL(string: $0) }

        let tokenValue = environment["AI_BACKEND_BEARER_TOKEN"]
            ?? bundle.object(forInfoDictionaryKey: "AI_BACKEND_BEARER_TOKEN") as? String
        let trimmedToken = tokenValue?.trimmingCharacters(in: .whitespacesAndNewlines)

        let timeoutValue = environment["AI_BACKEND_TIMEOUT_SECONDS"]
            ?? bundle.object(forInfoDictionaryKey: "AI_BACKEND_TIMEOUT_SECONDS") as? String
        let timeout = timeoutValue.flatMap(Double.init) ?? 25

        let retryValue = environment["AI_BACKEND_RETRY_COUNT"]
            ?? bundle.object(forInfoDictionaryKey: "AI_BACKEND_RETRY_COUNT") as? String
        let retryCount = max(0, retryValue.flatMap(Int.init) ?? 1)

        return AIBackendConfiguration(
            provider: baseURL == nil ? .localMock : provider,
            baseURL: baseURL,
            bearerToken: trimmedToken?.isEmpty == false ? trimmedToken : nil,
            timeout: timeout,
            retryCount: retryCount
        )
    }
}
