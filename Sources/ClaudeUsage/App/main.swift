import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsStore()
        let viewModel = UsageViewModel(settings: settings)
        statusItemController = StatusItemController(viewModel: viewModel, settings: settings)
        viewModel.start()
    }
}

let app = NSApplication.shared
// Top-level constant: NSApplication.delegate is weak, so this binding must stay
// at main.swift top level (program lifetime) — do not move into a function.
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only — no Dock icon, no main window.
app.setActivationPolicy(.accessory)
app.run()
