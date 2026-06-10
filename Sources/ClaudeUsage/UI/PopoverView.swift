import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var settings: SettingsStore
    @StateObject private var launchAtLogin = LaunchAtLogin()
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            Divider()
            footer
            if showSettings {
                Divider()
                SettingsSection(settings: settings, launchAtLogin: launchAtLogin)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Image(systemName: "gauge.with.needle")
                .foregroundStyle(.orange)
            Text("Claude Usage")
                .font(.headline)
            Spacer()
            if case .loading = viewModel.state {
                ProgressView().controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if case .failed(let message, _) = viewModel.state {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let snapshot = viewModel.currentSnapshot {
            VStack(spacing: 10) {
                UsageBarRow(title: "Session (5h)", window: snapshot.fiveHour)
                UsageBarRow(title: "Weekly · all models", window: snapshot.sevenDay)
                if snapshot.sevenDayOpus != nil {
                    UsageBarRow(title: "Weekly · Opus", window: snapshot.sevenDayOpus)
                }
            }
        } else if case .loading = viewModel.state {
            Text("Loading usage…")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        }
    }

    private var footer: some View {
        HStack {
            if let fetchedAt = viewModel.currentSnapshot?.fetchedAt {
                Text("Updated \(fetchedAt, format: .dateTime.hour().minute())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showSettings.toggle() }
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Claude Usage")
        }
    }
}
