import SwiftUI

/// One labeled progress row in the popover: title, percentage, bar, reset countdown.
struct UsageBarRow: View {
    let title: String
    let window: UsageWindow?

    private var barColor: Color {
        guard let window else { return .gray }
        switch window.utilization {
        case ..<50: return .green
        case ..<80: return .yellow
        default: return .red
        }
    }

    /// Absolute reset time in the Mac's local timezone — time only when today,
    /// weekday + time otherwise (weekly windows reset days ahead).
    static func localTimeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.callout.weight(.medium))
                Spacer()
                if let window {
                    Text("\(Int(window.utilization.rounded()))%")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(barColor)
                } else {
                    Text("—")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: window?.displayFraction ?? 0)
                .progressViewStyle(.linear)
                .tint(barColor)
            if let resetsAt = window?.resetsAt {
                Text("Resets \(resetsAt, format: .relative(presentation: .named)) · \(Self.localTimeLabel(for: resetsAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
