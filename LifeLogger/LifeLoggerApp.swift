import SwiftUI
import SwiftData
import UserNotifications
import AppKit

@main
struct LifeLoggerApp: App {
    @StateObject private var tracker: ActivityTracker
    @StateObject private var menuBar = MenuBarController()
    @StateObject private var notchHUD = NotchHUDController()
    @StateObject private var localContext = LocalContextService()
    @StateObject private var friendShare = FriendShareCoordinator()
    @StateObject private var sparkleUpdater = SparkleUpdaterController()
    @State private var pomodoroForHotkey = PomodoroTimer()
    @State private var hotkeyMonitor = GlobalHotkeyMonitor()

    private static let sharedModelContainer: ModelContainer = ModelContainerFactory.makeContainer()

    init() {
        SecurityBootstrap.run()
        if MessengerConsentStore.hasConsented {
            BloomieCloudAuthService.shared.configureIfNeeded()
        }

        let context = ModelContext(Self.sharedModelContainer)
        _tracker = StateObject(wrappedValue: ActivityTracker(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(tracker)
                .environmentObject(localContext)
                .environmentObject(friendShare)
                .environmentObject(AppLanguageStore.shared)
                .modelContainer(Self.sharedModelContainer)
                .localizedRefresh()
                .environment(\.locale, AppLanguageStore.shared.effectiveLanguage.locale)
                .onOpenURL { url in
                    friendShare.handleIncomingURL(url)
                }
                .onAppear {
                    bootstrapOnLaunch()
                }
                .onDisappear {
                    localContext.stop()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 720)

        Settings {
            CategorySettingsView()
                .modelContainer(Self.sharedModelContainer)
                .environmentObject(AppLanguageStore.shared)
                .localizedRefresh()
                .environment(\.locale, AppLanguageStore.shared.effectiveLanguage.locale)
        }
    }

    @MainActor
    private func bootstrapOnLaunch() {
        tracker.requestPermissions()
        let context = ModelContext(Self.sharedModelContainer)
        menuBar.setup(tracker: tracker, friendShare: friendShare, updater: sparkleUpdater) {
            let engine = FocusStatisticsEngine(modelContext: context)
            let summary = engine.summary()
            let apps = engine.topApps(limit: 3)
            return (summary.focusRatio, apps)
        }
        notchHUD.show(tracker: tracker, friendShare: friendShare)
        requestNotificationPermission()
        localContext.start()
        runRetentionIfNeeded(context: context)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            FocusStatisticsEngine(modelContext: context).repairInflatedSegments()
            startMessengerSyncIfNeeded()
        }

        pomodoroForHotkey.attach(tracker: tracker)
        hotkeyMonitor.start(tracker: tracker) {
            pomodoroForHotkey.toggleStartStop()
        }

        if !tracker.isTracking {
            tracker.startTracking()
        }
    }

    @MainActor
    private func startMessengerSyncIfNeeded() {
        guard MessengerConsentStore.hasConsented else { return }
        BloomieCloudAuthService.shared.configureIfNeeded()
        guard BloomieCloudAuthService.shared.isSignedIn,
              let uid = BloomieCloudAuthService.shared.currentUID else { return }
        let ctx = MessengerModelContainer.mainContext
        MessengerRepository.bootstrap(context: ctx)
        BloomieCloudChatService.shared.startInboxSync(myUID: uid, context: ctx)
    }

    @MainActor
    private func runRetentionIfNeeded(context: ModelContext) {
        guard RetentionPolicyStore.isEnabled else { return }
        let calendar = Calendar.current
        if let last = RetentionPolicyStore.lastRunDate,
           calendar.isDateInToday(last) {
            return
        }
        let engine = FocusStatisticsEngine(modelContext: context)
        _ = engine.purgeSegments(olderThan: RetentionPolicyStore.retentionDays)
        RetentionPolicyStore.lastRunDate = Date()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
