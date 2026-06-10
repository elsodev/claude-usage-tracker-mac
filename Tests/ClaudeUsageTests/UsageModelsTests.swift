import XCTest
@testable import ClaudeUsage

final class UsageModelsTests: XCTestCase {

    func testDecodesFullResponse() throws {
        let json = """
        {
            "five_hour": {"utilization": 42, "resets_at": "2026-06-11T08:00:00+00:00"},
            "seven_day": {"utilization": 31.5, "resets_at": "2026-06-15T00:00:00Z"},
            "seven_day_opus": {"utilization": 0, "resets_at": null}
        }
        """
        let snapshot = try UsageSnapshot.decode(from: Data(json.utf8), fetchedAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(snapshot.fiveHour?.utilization, 42)
        XCTAssertEqual(snapshot.sevenDay?.utilization, 31.5)
        XCTAssertEqual(snapshot.sevenDayOpus?.utilization, 0)
        XCTAssertNil(snapshot.sevenDayOpus?.resetsAt)

        let expectedReset = ISO8601DateFormatter().date(from: "2026-06-11T08:00:00+00:00")
        XCTAssertEqual(snapshot.fiveHour?.resetsAt, expectedReset)
    }

    func testDecodesMissingOpusAndUnknownKeys() throws {
        let json = """
        {
            "five_hour": {"utilization": 7, "resets_at": "2026-06-11T08:00:00Z"},
            "seven_day": {"utilization": 12, "resets_at": "2026-06-15T00:00:00Z"},
            "some_future_field": {"whatever": true}
        }
        """
        let snapshot = try UsageSnapshot.decode(from: Data(json.utf8), fetchedAt: Date())
        XCTAssertNil(snapshot.sevenDayOpus)
        XCTAssertEqual(snapshot.fiveHour?.utilization, 7)
    }

    func testDecodesFractionalSecondsDate() throws {
        let json = """
        {"five_hour": {"utilization": 1, "resets_at": "2026-06-11T08:00:00.123Z"}}
        """
        let snapshot = try UsageSnapshot.decode(from: Data(json.utf8), fetchedAt: Date())
        XCTAssertNotNil(snapshot.fiveHour?.resetsAt)
    }

    func testEmptyObjectDecodesToEmptySnapshot() throws {
        let snapshot = try UsageSnapshot.decode(from: Data("{}".utf8), fetchedAt: Date())
        XCTAssertNil(snapshot.fiveHour)
        XCTAssertNil(snapshot.sevenDay)
        XCTAssertNil(snapshot.sevenDayOpus)
    }

    func testGarbageThrows() {
        XCTAssertThrowsError(try UsageSnapshot.decode(from: Data("not json".utf8), fetchedAt: Date()))
    }

    func testUtilizationClampedForDisplay() {
        let window = UsageWindow(utilization: 130, resetsAt: nil)
        XCTAssertEqual(window.displayFraction, 1.0)
        let negative = UsageWindow(utilization: -5, resetsAt: nil)
        XCTAssertEqual(negative.displayFraction, 0.0)
    }
}
