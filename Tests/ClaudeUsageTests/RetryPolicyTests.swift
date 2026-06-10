import XCTest
@testable import ClaudeUsage

final class RetryPolicyTests: XCTestCase {

    // MARK: Retry-After parsing

    func testParsesSecondsValue() {
        XCTAssertEqual(RetryPolicy.parseRetryAfter("120"), 120)
    }

    func testParsesHTTPDateValue() {
        let now = Date(timeIntervalSince1970: 1_445_412_480) // 2015-10-21 07:28:00 GMT
        let delay = RetryPolicy.parseRetryAfter("Wed, 21 Oct 2015 07:30:00 GMT", now: now)
        XCTAssertEqual(delay ?? -1, 120, accuracy: 1)
    }

    func testNilAndGarbageReturnNil() {
        XCTAssertNil(RetryPolicy.parseRetryAfter(nil))
        XCTAssertNil(RetryPolicy.parseRetryAfter("soon"))
    }

    // MARK: Backoff delays

    func testRetryAfterHeaderWinsAndIsClamped() {
        XCTAssertEqual(
            RetryPolicy.nextDelay(retryAfterSeconds: 90, consecutiveFailures: 1, baseInterval: 60), 90
        )
        // Below the floor → clamped up so we never hammer.
        XCTAssertEqual(
            RetryPolicy.nextDelay(retryAfterSeconds: 5, consecutiveFailures: 1, baseInterval: 60), 60
        )
        // Absurdly long → capped at one hour.
        XCTAssertEqual(
            RetryPolicy.nextDelay(retryAfterSeconds: 90_000, consecutiveFailures: 1, baseInterval: 60), 3600
        )
    }

    func testExponentialBackoffWithoutHeader() {
        XCTAssertEqual(RetryPolicy.nextDelay(retryAfterSeconds: nil, consecutiveFailures: 1, baseInterval: 60), 120)
        XCTAssertEqual(RetryPolicy.nextDelay(retryAfterSeconds: nil, consecutiveFailures: 2, baseInterval: 60), 240)
        XCTAssertEqual(RetryPolicy.nextDelay(retryAfterSeconds: nil, consecutiveFailures: 3, baseInterval: 60), 480)
    }

    func testExponentialBackoffIsCapped() {
        XCTAssertEqual(
            RetryPolicy.nextDelay(retryAfterSeconds: nil, consecutiveFailures: 10, baseInterval: 300), 1800
        )
    }

    // MARK: Popover-open staleness check

    func testRefreshOnOpenOnlyWhenStale() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(RetryPolicy.shouldRefresh(lastFetchedAt: nil, backoffUntil: nil, now: now))
        XCTAssertFalse(RetryPolicy.shouldRefresh(
            lastFetchedAt: now.addingTimeInterval(-10), backoffUntil: nil, now: now
        ))
        XCTAssertTrue(RetryPolicy.shouldRefresh(
            lastFetchedAt: now.addingTimeInterval(-31), backoffUntil: nil, now: now
        ))
    }

    func testNoRefreshDuringBackoff() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(RetryPolicy.shouldRefresh(
            lastFetchedAt: now.addingTimeInterval(-600),
            backoffUntil: now.addingTimeInterval(60),
            now: now
        ))
        // Backoff expired → allowed again.
        XCTAssertTrue(RetryPolicy.shouldRefresh(
            lastFetchedAt: now.addingTimeInterval(-600),
            backoffUntil: now.addingTimeInterval(-1),
            now: now
        ))
    }
}
