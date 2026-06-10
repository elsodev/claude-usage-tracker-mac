import Foundation
import Combine

/// User preferences backed by UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let refreshInterval = "refreshIntervalSeconds"
        static let notificationThreshold = "notificationThresholdPercent"
        static let notificationsEnabled = "notificationsEnabled"
        static let lastNotifiedResetAt = "lastNotifiedResetAt"
    }

    static let refreshIntervalChoices: [TimeInterval] = [30, 60, 120, 300]

    private let defaults: UserDefaults

    @Published var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }
    @Published var notificationThreshold: Double {
        didSet { defaults.set(notificationThreshold, forKey: Keys.notificationThreshold) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    var lastNotifiedResetAt: Date? {
        get { defaults.object(forKey: Keys.lastNotifiedResetAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastNotifiedResetAt) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedInterval = defaults.double(forKey: Keys.refreshInterval)
        self.refreshInterval = storedInterval > 0 ? storedInterval : 60
        let storedThreshold = defaults.double(forKey: Keys.notificationThreshold)
        self.notificationThreshold = storedThreshold > 0 ? storedThreshold : 80
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
    }
}
