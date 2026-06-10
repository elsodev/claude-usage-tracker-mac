import XCTest
@testable import ClaudeUsage

final class NotificationDecisionTests: XCTestCase {

    private let windowA = Date(timeIntervalSince1970: 1_000_000)
    private let windowB = Date(timeIntervalSince1970: 1_018_000) // next 5h window

    func testFiresWhenCrossingThreshold() {
        let decision = NotificationDecision.evaluate(
            utilization: 85, resetsAt: windowA, threshold: 80, lastNotifiedResetAt: nil
        )
        XCTAssertTrue(decision.shouldNotify)
        XCTAssertEqual(decision.notifiedResetAt, windowA)
    }

    func testDoesNotFireBelowThreshold() {
        let decision = NotificationDecision.evaluate(
            utilization: 79.9, resetsAt: windowA, threshold: 80, lastNotifiedResetAt: nil
        )
        XCTAssertFalse(decision.shouldNotify)
    }

    func testDoesNotFireTwiceInSameWindow() {
        let decision = NotificationDecision.evaluate(
            utilization: 95, resetsAt: windowA, threshold: 80, lastNotifiedResetAt: windowA
        )
        XCTAssertFalse(decision.shouldNotify)
    }

    func testReArmsOnNewWindow() {
        let decision = NotificationDecision.evaluate(
            utilization: 90, resetsAt: windowB, threshold: 80, lastNotifiedResetAt: windowA
        )
        XCTAssertTrue(decision.shouldNotify)
        XCTAssertEqual(decision.notifiedResetAt, windowB)
    }

    func testNilResetDateFiresOncePerUnknownWindow() {
        let first = NotificationDecision.evaluate(
            utilization: 90, resetsAt: nil, threshold: 80, lastNotifiedResetAt: nil
        )
        XCTAssertTrue(first.shouldNotify)
        // With no reset date we record a sentinel; a repeat with the same sentinel stays quiet.
        let second = NotificationDecision.evaluate(
            utilization: 95, resetsAt: nil, threshold: 80, lastNotifiedResetAt: first.notifiedResetAt
        )
        XCTAssertFalse(second.shouldNotify)
    }

    func testExactlyAtThresholdFires() {
        let decision = NotificationDecision.evaluate(
            utilization: 80, resetsAt: windowA, threshold: 80, lastNotifiedResetAt: nil
        )
        XCTAssertTrue(decision.shouldNotify)
    }
}
