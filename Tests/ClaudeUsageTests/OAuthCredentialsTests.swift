import XCTest
@testable import ClaudeUsage

final class OAuthCredentialsTests: XCTestCase {

    func testParsesClaudeCodeKeychainJSON() throws {
        let json = """
        {
            "claudeAiOauth": {
                "accessToken": "sk-ant-oat01-abc",
                "refreshToken": "sk-ant-ort01-def",
                "expiresAt": 1781000000000,
                "scopes": ["user:inference", "user:profile"],
                "subscriptionType": "max"
            }
        }
        """
        let credentials = try OAuthCredentials.parse(from: Data(json.utf8))
        XCTAssertEqual(credentials.accessToken, "sk-ant-oat01-abc")
        XCTAssertEqual(credentials.expiresAt, Date(timeIntervalSince1970: 1_781_000_000))
    }

    func testMissingOAuthSectionThrows() {
        let json = #"{"somethingElse": {}}"#
        XCTAssertThrowsError(try OAuthCredentials.parse(from: Data(json.utf8))) { error in
            XCTAssertEqual(error as? CredentialsError, .malformedCredentials)
        }
    }

    func testEmptyAccessTokenThrows() {
        let json = #"{"claudeAiOauth": {"accessToken": "", "expiresAt": 1}}"#
        XCTAssertThrowsError(try OAuthCredentials.parse(from: Data(json.utf8))) { error in
            XCTAssertEqual(error as? CredentialsError, .malformedCredentials)
        }
    }

    func testExpiryCheck() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expired = OAuthCredentials(accessToken: "t", expiresAt: now.addingTimeInterval(-60))
        let valid = OAuthCredentials(accessToken: "t", expiresAt: now.addingTimeInterval(60))
        let unknown = OAuthCredentials(accessToken: "t", expiresAt: nil)

        XCTAssertTrue(expired.isExpired(at: now))
        XCTAssertFalse(valid.isExpired(at: now))
        XCTAssertFalse(unknown.isExpired(at: now), "missing expiry should not block an attempt")
    }

    func testMissingExpiresAtStillParses() throws {
        let json = #"{"claudeAiOauth": {"accessToken": "sk-ant-oat01-abc"}}"#
        let credentials = try OAuthCredentials.parse(from: Data(json.utf8))
        XCTAssertNil(credentials.expiresAt)
    }
}
