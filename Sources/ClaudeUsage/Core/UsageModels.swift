import Foundation

/// One usage window (5-hour session, 7-day, or 7-day Opus) as reported by the
/// Anthropic OAuth usage endpoint.
struct UsageWindow: Equatable, Sendable {
    /// Percentage 0–100 (the API may exceed 100 briefly).
    let utilization: Double
    let resetsAt: Date?

    /// Fraction clamped to 0…1 for progress bars.
    var displayFraction: Double {
        min(max(utilization / 100.0, 0.0), 1.0)
    }
}

struct UsageSnapshot: Equatable, Sendable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDayOpus: UsageWindow?
    let fetchedAt: Date
}

enum UsageDecodingError: Error, Equatable {
    case invalidJSON
}

extension UsageSnapshot {
    /// Tolerant decoder for the usage endpoint response. Unknown keys are ignored,
    /// every window is optional, and dates may carry fractional seconds or not.
    static func decode(from data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageDecodingError.invalidJSON
        }
        return UsageSnapshot(
            fiveHour: window(from: root["five_hour"]),
            sevenDay: window(from: root["seven_day"]),
            sevenDayOpus: window(from: root["seven_day_opus"]),
            fetchedAt: fetchedAt
        )
    }

    private static func window(from value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any],
              let utilization = (dict["utilization"] as? NSNumber)?.doubleValue else {
            return nil
        }
        return UsageWindow(
            utilization: utilization,
            resetsAt: (dict["resets_at"] as? String).flatMap(ISO8601.parse)
        )
    }
}

/// ISO8601 parsing that accepts both fractional and whole-second timestamps.
enum ISO8601 {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let whole = ISO8601DateFormatter()

    static func parse(_ string: String) -> Date? {
        fractional.date(from: string) ?? whole.date(from: string)
    }
}
