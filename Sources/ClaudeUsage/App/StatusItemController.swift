import AppKit
import SwiftUI
import Combine

/// Owns the NSStatusItem and the popover, and keeps the menu bar title in sync
/// with the view model.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let viewModel: UsageViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: UsageViewModel, settings: SettingsStore) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel, settings: settings)
        )

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "gauge.with.needle",
                accessibilityDescription: "Claude usage"
            )
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)
        updateTitle()
    }

    private func updateTitle() {
        statusItem.button?.title = " \(viewModel.statusItemTitle)"
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            viewModel.refreshIfStale()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
