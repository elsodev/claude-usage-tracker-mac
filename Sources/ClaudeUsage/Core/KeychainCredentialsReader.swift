import Foundation
import Security

protocol CredentialsProviding: Sendable {
    func loadCredentials() throws -> OAuthCredentials
}

/// Reads the Claude Code OAuth credentials from the macOS Keychain.
/// Strictly read-only: no writes, no token refresh, so Claude Code's own
/// session can never be disturbed by this app.
struct KeychainCredentialsReader: CredentialsProviding {
    static let serviceName = "Claude Code-credentials"

    func loadCredentials() throws -> OAuthCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw CredentialsError.malformedCredentials
            }
            return try OAuthCredentials.parse(from: data)
        case errSecItemNotFound:
            throw CredentialsError.keychainItemNotFound
        default:
            throw CredentialsError.keychainAccessDenied(status: status)
        }
    }
}
