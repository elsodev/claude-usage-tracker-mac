import Foundation

enum UsageAPIError: Error, Equatable {
    case unauthorized
    case rateLimited(retryAfterSeconds: TimeInterval?)
    case httpError(status: Int)
    case network(description: String)
    case decoding

    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Token expired — run any Claude Code command to refresh it."
        case .rateLimited:
            return "Rate limited by Anthropic — backing off."
        case .httpError(let status):
            return "Anthropic usage API returned HTTP \(status)."
        case .network(let description):
            return "Network error: \(description)"
        case .decoding:
            return "Could not read the usage API response (format may have changed)."
        }
    }
}

protocol UsageFetching: Sendable {
    func fetchUsage(accessToken: String) async throws -> UsageSnapshot
}

/// Calls the same usage endpoint Claude Code's /usage command uses.
struct UsageAPIClient: UsageFetching {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage(accessToken: String) async throws -> UsageSnapshot {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageAPIError.network(description: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UsageAPIError.network(description: "non-HTTP response")
        }
        if http.statusCode != 200 {
            let headers = http.allHeaderFields
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: "; ")
            let body = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
            NSLog("ClaudeUsage DIAG: status=%d headers=[%@] body=%@", http.statusCode, headers, body)
        }
        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw UsageAPIError.unauthorized
        case 429:
            let retryAfter = RetryPolicy.parseRetryAfter(
                http.value(forHTTPHeaderField: "Retry-After")
            )
            throw UsageAPIError.rateLimited(retryAfterSeconds: retryAfter)
        default:
            throw UsageAPIError.httpError(status: http.statusCode)
        }

        do {
            return try UsageSnapshot.decode(from: data, fetchedAt: Date())
        } catch {
            throw UsageAPIError.decoding
        }
    }
}
