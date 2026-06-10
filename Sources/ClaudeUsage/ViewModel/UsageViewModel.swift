import Foundation
import Combine

/// Drives polling and exposes display state to both the status item and popover.
@MainActor
final class UsageViewModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case loaded(UsageSnapshot)
        /// Failure keeps the last good snapshot so the popover never goes blank.
        case failed(message: String, lastSnapshot: UsageSnapshot?)
    }

    @Published private(set) var state: LoadState = .loading

    let settings: SettingsStore

    private let credentialsProvider: CredentialsProviding
    private let apiClient: UsageFetching
    private let notificationManager: NotificationManager
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Rate-limit backoff: while set in the future, no network calls are made.
    private var backoffUntil: Date?
    private var consecutiveRateLimits = 0

    /// Last good snapshot regardless of current state.
    var currentSnapshot: UsageSnapshot? {
        switch state {
        case .loaded(let snapshot): return snapshot
        case .failed(_, let snapshot): return snapshot
        case .loading: return nil
        }
    }

    /// Text for the menu bar, e.g. "42%". Falls back to "–" before first load
    /// or "!" when failing with no data.
    var statusItemTitle: String {
        if let utilization = currentSnapshot?.fiveHour?.utilization {
            return "\(Int(utilization.rounded()))%"
        }
        if case .failed = state { return "!" }
        return "–"
    }

    init(
        settings: SettingsStore,
        credentialsProvider: CredentialsProviding = KeychainCredentialsReader(),
        apiClient: UsageFetching = UsageAPIClient()
    ) {
        self.settings = settings
        self.credentialsProvider = credentialsProvider
        self.apiClient = apiClient
        self.notificationManager = NotificationManager(settings: settings)

        settings.$refreshInterval
            .removeDuplicates()
            .dropFirst() // start() schedules the initial timer
            .sink { [weak self] interval in self?.schedule(interval: interval) }
            .store(in: &cancellables)
    }

    func start() {
        schedule(interval: settings.refreshInterval)
        refresh()
    }

    func refresh() {
        if let backoffUntil, backoffUntil > Date() {
            fail(with: Self.rateLimitMessage(until: backoffUntil))
            return
        }
        Task { await self.performRefresh() }
    }

    /// Cheap refresh for popover opens: skips the network when data is fresh
    /// or while waiting out a rate-limit cooldown.
    func refreshIfStale() {
        guard RetryPolicy.shouldRefresh(
            lastFetchedAt: currentSnapshot?.fetchedAt,
            backoffUntil: backoffUntil
        ) else { return }
        refresh()
    }

    private func schedule(interval: TimeInterval) {
        timer?.invalidate()
        // .common mode so polling keeps firing while menus/popovers track events.
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        newTimer.tolerance = interval * 0.1
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    @MainActor
    private func performRefresh() async {
        do {
            let credentials = try credentialsProvider.loadCredentials()
            if credentials.isExpired() {
                fail(with: UsageAPIError.unauthorized.userMessage)
                return
            }
            let snapshot = try await apiClient.fetchUsage(accessToken: credentials.accessToken)
            backoffUntil = nil
            consecutiveRateLimits = 0
            state = .loaded(snapshot)
            notificationManager.handle(snapshot: snapshot)
        } catch let error as CredentialsError {
            fail(with: error.userMessage)
        } catch UsageAPIError.rateLimited(let retryAfterSeconds) {
            consecutiveRateLimits += 1
            let delay = RetryPolicy.nextDelay(
                retryAfterSeconds: retryAfterSeconds,
                consecutiveFailures: consecutiveRateLimits,
                baseInterval: settings.refreshInterval
            )
            let until = Date().addingTimeInterval(delay)
            backoffUntil = until
            fail(with: Self.rateLimitMessage(until: until))
        } catch let error as UsageAPIError {
            fail(with: error.userMessage)
        } catch {
            fail(with: error.localizedDescription)
        }
    }

    private func fail(with message: String) {
        state = .failed(message: message, lastSnapshot: currentSnapshot)
    }

    private static func rateLimitMessage(until: Date) -> String {
        "Rate limited by Anthropic — retrying after \(until.formatted(date: .omitted, time: .shortened))."
    }
}
