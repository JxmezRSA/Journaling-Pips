import Foundation

enum AIBackendEndpoint {
    case tradeReview
    case chartAnalysis

    func path(for provider: AIBackendProvider) -> String {
        switch self {
        case .tradeReview:
            return provider.reviewPath
        case .chartAnalysis:
            return provider.chartAnalysisPath
        }
    }
}

struct AIStreamingChunk: Codable, Sendable {
    let text: String
    let isFinal: Bool
}

final class AIBackendService {
    private let configuration: AIBackendConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: AIBackendConfiguration = .current(),
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    var isConfigured: Bool {
        configuration.isConfigured
    }

    var provider: AIBackendProvider {
        configuration.provider
    }

    func post<Request: Encodable, Response: Decodable>(
        _ requestPayload: Request,
        endpoint: AIBackendEndpoint,
        responseType: Response.Type = Response.self
    ) async throws -> Response {
        guard configuration.isConfigured, let baseURL = configuration.baseURL else {
            debugPrint("AI CACHE HIT:", "backend not configured, local fallback required")
            throw AIServiceError.backendNotConfigured
        }

        debugPrint("AI REQUEST START:", configuration.provider.rawValue, endpoint.path(for: configuration.provider))
        let url = baseURL.appending(path: endpoint.path(for: configuration.provider))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.provider.rawValue, forHTTPHeaderField: "X-AI-Provider")

        if let bearerToken = configuration.bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try encoder.encode(requestPayload)

        var latestError: Error?
        for attempt in 0...configuration.retryCount {
            do {
                debugPrint("AI REQUEST SENT:", url.absoluteString, "attempt", attempt + 1)
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw AIServiceError.requestFailed("AI backend failed with status \(httpResponse.statusCode).")
                }

                debugPrint("AI RESPONSE RECEIVED:", httpResponse.statusCode)
                return try decoder.decode(Response.self, from: data)
            } catch {
                latestError = map(error)
                if attempt < configuration.retryCount {
                    try? await Task.sleep(nanoseconds: UInt64(350_000_000 * UInt64(attempt + 1)))
                }
            }
        }

        debugPrint("AI BACKEND FAILED:", String(describing: latestError ?? AIServiceError.invalidResponse))
        throw latestError ?? AIServiceError.invalidResponse
    }

    func stream<Request: Encodable>(
        _ requestPayload: Request,
        endpoint: AIBackendEndpoint
    ) -> AsyncThrowingStream<AIStreamingChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIServiceError.requestFailed("Streaming transport is backend-ready but not enabled in the UI yet."))
        }
    }

    func healthCheck() async -> Bool {
        guard configuration.isConfigured, let baseURL = configuration.baseURL else {
            return false
        }

        let endpoint = baseURL.appending(path: "ai/health")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = min(configuration.timeout, 8)
        request.setValue(configuration.provider.rawValue, forHTTPHeaderField: "X-AI-Provider")

        if let bearerToken = configuration.bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            debugPrint("AI BACKEND FAILED:", String(describing: map(error)))
            return false
        }
    }

    private func map(_ error: Error) -> AIServiceError {
        if let aiError = error as? AIServiceError {
            return aiError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .requestFailed("AI backend timed out. Showing local coaching preview.")
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return .requestFailed("AI backend is offline. Showing local coaching preview.")
            default:
                return .requestFailed("AI backend is unavailable. Showing local coaching preview.")
            }
        }

        return .requestFailed("AI backend is unavailable. Showing local coaching preview.")
    }
}
