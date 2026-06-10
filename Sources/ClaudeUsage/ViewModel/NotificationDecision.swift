import Foundation

/// Pure decision logic for threshold notifications: fire once per usage window,
/// re-arm when the window's reset time changes.
struct NotificationDecision: Equatable {
    let shouldNotify: Bool
    /// The reset date to record as "already notified" (sentinel when unknown).
    let notifiedResetAt: Date?

    /// Sentinel recorded when the API gives no reset date, so we still only
    /// notify once rather than on every poll.
    static let unknownWindowSentinel = Date(timeIntervalSince1970: 0)

    static func evaluate(
        utilization: Double,
        resetsAt: Date?,
        threshold: Double,
        lastNotifiedResetAt: Date?
    ) -> NotificationDecision {
        guard utilization >= threshold else {
            return NotificationDecision(shouldNotify: false, notifiedResetAt: lastNotifiedResetAt)
        }
        let windowMarker = resetsAt ?? unknownWindowSentinel
        guard windowMarker != lastNotifiedResetAt else {
            return NotificationDecision(shouldNotify: false, notifiedResetAt: lastNotifiedResetAt)
        }
        return NotificationDecision(shouldNotify: true, notifiedResetAt: windowMarker)
    }
}
