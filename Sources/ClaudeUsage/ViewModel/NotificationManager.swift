import Foundation
import UserNotifications

/// Posts the threshold-crossing notification. The fire/skip decision lives in
/// NotificationDecision (pure, unit-tested); this class only talks to macOS.
@MainActor
final class NotificationManager {
    private let settings: SettingsStore
    private var permissionRequested = false

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func handle(snapshot: UsageSnapshot) {
        guard settings.notificationsEnabled, let fiveHour = snapshot.fiveHour else { return }

        let decision = NotificationDecision.evaluate(
            utilization: fiveHour.utilization,
            resetsAt: fiveHour.resetsAt,
            threshold: settings.notificationThreshold,
            lastNotifiedResetAt: settings.lastNotifiedResetAt
        )
        guard decision.shouldNotify else { return }

        settings.lastNotifiedResetAt = decision.notifiedResetAt
        post(utilization: fiveHour.utilization, resetsAt: fiveHour.resetsAt)
    }

    private func post(utilization: Double, resetsAt: Date?) {
        let center = UNUserNotificationCenter.current()
        // Identifier keyed on the usage window, not the percentage, so one window
        // gets exactly one notification and windows never collide.
        let windowKey = resetsAt.map { String($0.timeIntervalSince1970) } ?? "unknown"
        let deliver: @Sendable () -> Void = {
            let content = UNMutableNotificationContent()
            content.title = "Claude session at \(Int(utilization))%"
            if let resetsAt {
                content.body = "Limit resets \(resetsAt.formatted(date: .omitted, time: .shortened))."
            } else {
                content.body = "You are approaching your 5-hour session limit."
            }
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "claude-usage-threshold-\(windowKey)",
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                if let error {
                    NSLog("ClaudeUsage: failed to post notification: \(error.localizedDescription)")
                }
            }
        }

        if permissionRequested {
            deliver()
        } else {
            permissionRequested = true
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                DispatchQueue.main.async { deliver() }
            }
        }
    }
}
