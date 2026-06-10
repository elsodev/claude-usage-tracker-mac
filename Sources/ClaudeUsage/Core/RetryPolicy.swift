import Foundation

/// Pure rate-limit/backoff policy. The usage endpoint has a low per-token quota;
/// after a 429 we must wait out the cooldown instead of retrying on schedule.
enum RetryPolicy {
    /// Minimum wait after any 429.
    static let minimumDelay: TimeInterval = 60
    /// Cap when the server tells us how long to wait.
    static let maximumServerDelay: TimeInterval = 3600
    /// Cap for our own exponential backoff when no Retry-After is given.
    static let maximumBackoff: TimeInterval = 1800
    /// Popover-open refreshes are skipped if data is fresher than this.
    static let stalenessThreshold: TimeInterval = 30

    /// Parses an HTTP Retry-After header value: either delta-seconds or an HTTP-date.
    static func parseRetryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else {
            return nil
        }
        if let seconds = TimeInterval(value) {
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: value) {
            return max(0, date.timeIntervalSince(now))
        }
        return nil
    }

    /// Delay before the next attempt after a 429. Server hint wins (clamped);
    /// otherwise exponential backoff from the polling interval.
    static func nextDelay(
        retryAfterSeconds: TimeInterval?,
        consecutiveFailures: Int,
        baseInterval: TimeInterval
    ) -> TimeInterval {
        if let retryAfterSeconds {
            return min(max(retryAfterSeconds, minimumDelay), maximumServerDelay)
        }
        let exponential = baseInterval * pow(2, Double(max(consecutiveFailures, 1)))
        return min(max(exponential, minimumDelay), maximumBackoff)
    }

    /// Whether a refresh should actually hit the network right now.
    static func shouldRefresh(lastFetchedAt: Date?, backoffUntil: Date?, now: Date = Date()) -> Bool {
        if let backoffUntil, backoffUntil > now {
            return false
        }
        guard let lastFetchedAt else { return true }
        return now.timeIntervalSince(lastFetchedAt) > stalenessThreshold
    }
}
