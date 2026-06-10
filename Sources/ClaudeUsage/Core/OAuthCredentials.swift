import Foundation

enum CredentialsError: Error, Equatable {
    case keychainItemNotFound
    case keychainAccessDenied(status: Int32)
    case malformedCredentials

    var userMessage: String {
        switch self {
        case .keychainItemNotFound:
            return "No Claude Code credentials found. Sign in with the Claude Code CLI first."
        case .keychainAccessDenied(let status):
            return "Keychain access denied (status \(status)). Click “Always Allow” when macOS asks."
        case .malformedCredentials:
            return "Claude Code credentials could not be read. Try signing in to Claude Code again."
        }
    }
}

/// The Claude Code OAuth credentials as stored in the macOS Keychain under the
/// service "Claude Code-credentials". Read-only — this app never refreshes or
/// rewrites the token.
struct OAuthCredentials: Equatable, Sendable {
    let accessToken: String
    let expiresAt: Date?

    func isExpired(at now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }

    /// Parses the keychain item payload: {"claudeAiOauth": {"accessToken": "...",
    /// "expiresAt": <epoch ms>, ...}}
    static func parse(from data: Data) throws -> OAuthCredentials {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty else {
            throw CredentialsError.malformedCredentials
        }
        let expiresAt = (oauth["expiresAt"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue / 1000.0)
        }
        return OAuthCredentials(accessToken: token, expiresAt: expiresAt)
    }
}
