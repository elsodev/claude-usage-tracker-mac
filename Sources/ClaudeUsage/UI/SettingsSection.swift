import SwiftUI

/// Collapsible settings area at the bottom of the popover.
struct SettingsSection: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var launchAtLogin: LaunchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Refresh every", selection: $settings.refreshInterval) {
                ForEach(SettingsStore.refreshIntervalChoices, id: \.self) { interval in
                    Text(label(for: interval)).tag(interval)
                }
            }
            .pickerStyle(.menu)

            Toggle("Notify at threshold", isOn: $settings.notificationsEnabled)
            if settings.notificationsEnabled {
                HStack {
                    Slider(value: $settings.notificationThreshold, in: 50...95, step: 5)
                    Text("\(Int(settings.notificationThreshold))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 32, alignment: .trailing)
                }
            }

            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            if let error = launchAtLogin.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .font(.callout)
    }

    private func label(for interval: TimeInterval) -> String {
        interval < 60 ? "\(Int(interval)) s" : "\(Int(interval / 60)) min"
    }
}
