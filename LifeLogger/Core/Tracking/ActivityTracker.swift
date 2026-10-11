import AppKit
import Foundation
import SwiftData
import Combine
import UserNotifications

@MainActor
final class ActivityTracker: ObservableObject {
    @Published private(set) var isTracking = false
    @Published private(set) var isPausedForPomodoroBreak = false
    @Published private(set) var isAutoPaused = false
    @Published private(set) var isAFK = false
    @Published private(set) var currentAppName: String = ""
    @Published private(set) var currentBundleIdentifier: String = ""
    @Published private(set) var currentWindowTitle: String = ""
    @Published private(set) var currentCategory: ActivityCategory = .other
    @Published private(set) var currentSegmentStart: Date?
    @Published private(set) var todayFocusRatio: Double = 0
    @Published private(set) var todayScreenOnSeconds: TimeInterval = 0
    @Published private(set) var isAccessibilityDegraded = false

    private var screenOnAccumulated: TimeInterval = 0
    private var screenOnSessionStart: Date?
    private var isScreenOn = true
    private var screenOnTickTimer: Timer?
    private static let screenOnDayKey = "lifelogger.screenOn.day"
    private static let screenOnSecondsKey = "lifelogger.screenOn.seconds"

    private let modelContext: ModelContext
    private let windowExtractor = WindowTitleExtractor.shared
    private let classifier = CategoryClassifier.shared
    private var afkDetector = AFKDetector(idleThreshold: 90)
    private var awaitingUserPresenceAfterWake = false

    private var samplingTimer: Timer?
    private var currentSegment: ActivitySegment?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var customRules: [CategoryMappingRule] = []

    // 집중 이탈 넛지 상태
    private var nonFocusStreakStart: Date?
    private var nudgedCurrentStreak = false
    private var lastNudgeAt: Date?

    // 휴식 리마인더 (#10)
    private var continuousFocusStart: Date?
    private var restNudgeSentForSession = false

    // 집중 모드 연동 (#19)
    private var focusModeWasActive = false
    private var trackingBeforeFocusMode = false
    private var focusObserver: NSObjectProtocol?
    private var systemObservers: [NSObjectProtocol] = []
    private var wasTrackingBeforeSleep = false
    private var permissionCheckTimer: Timer?
    private var lastStatisticsSync = Date.distantPast
    private let statisticsSyncInterval: TimeInterval = 5

    private var statisticsEngine: FocusStatisticsEngine {
        FocusStatisticsEngine(modelContext: modelContext)
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCustomRules()
        loadScreenOnPersistedTotal()
        isScreenOn = false
        beginScreenOnSession(at: Date())
        startScreenOnTickTimer()
        restoreTrackingStateFromAppGroup()
        observeFocusModeIfNeeded()
        registerSystemObservers()
        startPermissionMonitoring()
    }

    func observeFocusModeIfNeeded() {
        guard FocusModeIntegrationStore.isEnabled else { return }
        focusObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.focus.status.changed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleFocusModeChange() }
        }
    }

    private func handleFocusModeChange() {
        guard FocusModeIntegrationStore.isEnabled else { return }
        let active = isLikelyFocusActiveHeuristic()
        if active && !focusModeWasActive {
            trackingBeforeFocusMode = isTracking
            if !isTracking { startTracking() }
        } else if !active && focusModeWasActive, !trackingBeforeFocusMode {
            stopTracking()
        }
        focusModeWasActive = active
    }

    /// 공개 Focus API 부재 시 Do Not Disturb 신호를 휴리스틱으로 해석 (graceful degrade)
    private func isLikelyFocusActiveHeuristic() -> Bool {
        UserDefaults.standard.bool(forKey: "com.apple.focus.activeHeuristic")
    }

    func syncFocusModeHeuristic(active: Bool) {
        UserDefaults.standard.set(active, forKey: "com.apple.focus.activeHeuristic")
        handleFocusModeChange()
    }

    // MARK: - Public API

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        isAFK = false
        AppGroupConstants.sharedDefaults.set(true, forKey: AppGroupConstants.Keys.isTrackingEnabled)

        registerWorkspaceObservers()
        beginNewSegment(force: true)
        startSamplingTimer()
        syncStatistics(force: true)
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        isAutoPaused = false
        AppGroupConstants.sharedDefaults.set(false, forKey: AppGroupConstants.Keys.isTrackingEnabled)

        stopSamplingTimer()
        closeCurrentSegment()
        removeWorkspaceObservers()
        resetNudgeStreak()
        resetRestReminder()
        syncStatistics(force: true)
    }

    func resumeFromAutoPause() {
        guard isAutoPaused else { return }
        isAutoPaused = false
        if !isTracking { startTracking() }
    }

    private func applyAutoPauseIfNeeded() {
        guard isTracking, !isPausedForPomodoroBreak else { return }
        let shouldPause = AutoPauseRuleStore.shouldAutoPause(appName: currentAppName)
        if shouldPause && !isAutoPaused {
            isAutoPaused = true
            closeCurrentSegment()
            stopSamplingTimer()
            resetNudgeStreak()
            resetRestReminder()
        } else if !shouldPause && isAutoPaused {
            isAutoPaused = false
            beginNewSegment(force: true)
            startSamplingTimer()
        }
    }

    func toggleTracking() {
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }

    func setAFKThreshold(seconds: TimeInterval) {
        afkDetector = AFKDetector(idleThreshold: seconds)
    }

    func pauseForPomodoroBreak() {
        isPausedForPomodoroBreak = true
        closeCurrentSegment()
        stopSamplingTimer()
        resetNudgeStreak()
        resetRestReminder()
        syncStatistics()
    }

    func resumeFromPomodoroBreak() {
        isPausedForPomodoroBreak = false
        if isTracking {
            beginNewSegment(force: true)
            startSamplingTimer()
            syncStatistics()
        }
    }

    func requestPermissions() {
        windowExtractor.requestAccessibilityPermissionIfNeeded()
        refreshAccessibilityDegradedState()
    }

    private func refreshAccessibilityDegradedState() {
        let trusted = windowExtractor.isAccessibilityTrusted
        isAccessibilityDegraded = isTracking && !trusted
    }

    private func startPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAccessibilityDegradedState() }
        }
        if let permissionCheckTimer {
            RunLoop.main.add(permissionCheckTimer, forMode: .common)
        }
    }

    // MARK: - System Sleep / Lock (#5)

    private func registerSystemObservers() {
        removeSystemObservers()

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let willSleep = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWillSleep() }
        }
        let didWake = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleDidWake() }
        }
        systemObservers.append(contentsOf: [willSleep, didWake])

        let distributed = DistributedNotificationCenter.default()
        let screenLock = distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWillSleep() }
        }
        let screenUnlock = distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleDidWake() }
        }
        let screensaverStart = distributed.addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWillSleep() }
        }
        let screensaverStop = distributed.addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleDidWake() }
        }
        systemObservers.append(contentsOf: [screenLock, screenUnlock, screensaverStart, screensaverStop])
    }

    private func removeSystemObservers() {
        for observer in systemObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        systemObservers.removeAll()
    }

    private func handleWillSleep() {
        endScreenOnSession(at: Date())
        wasTrackingBeforeSleep = isTracking
        guard isTracking else { return }
        AppLogger.tracking.info("System sleep/lock — closing open segment")
        closeCurrentSegment(at: Date())
        stopSamplingTimer()
    }

    private func handleDidWake() {
        beginScreenOnSession(at: Date())
        guard wasTrackingBeforeSleep, !isPausedForPomodoroBreak, !isAutoPaused else { return }
        AppLogger.tracking.info("System wake/unlock — awaiting user presence before tracking")
        if !isTracking { isTracking = true }
        isAFK = true
        awaitingUserPresenceAfterWake = true
        startSamplingTimer()
        syncStatistics()
    }

    private func checkMidnightBoundary(now: Date = Date()) {
        guard let segment = currentSegment, let segmentStart = currentSegmentStart else { return }
        let calendar = Calendar.current
        guard !calendar.isDate(segmentStart, inSameDayAs: now) else { return }
        let midnight = calendar.startOfDay(for: now)
        AppLogger.tracking.info("Midnight boundary — splitting segment")
        closeCurrentSegment(at: midnight)
        if isTracking, !isPausedForPomodoroBreak, !isAFK, !isAutoPaused {
            beginNewSegment(force: true, at: midnight)
        }
    }

    // MARK: - Workspace Observers

    private func registerWorkspaceObservers() {
        removeWorkspaceObservers()

        let center = NSWorkspace.shared.notificationCenter
        let activate = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppSwitch()
            }
        }
        workspaceObservers.append(activate)
    }

    private func removeWorkspaceObservers() {
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private func handleAppSwitch() {
        guard isTracking, !isPausedForPomodoroBreak else { return }
        closeCurrentSegment()
        beginNewSegment(force: true)
    }

    // MARK: - Sampling

    private func startSamplingTimer() {
        stopSamplingTimer()
        samplingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleCurrentActivity()
            }
        }
        if let samplingTimer {
            RunLoop.main.add(samplingTimer, forMode: .common)
        }
    }

    private func stopSamplingTimer() {
        samplingTimer?.invalidate()
        samplingTimer = nil
    }

    private func sampleCurrentActivity() {
        syncTrackingStateFromAppGroupIfNeeded()
        checkMidnightBoundary()
        refreshAccessibilityDegradedState()
        guard isTracking, !isPausedForPomodoroBreak, !isAutoPaused else {
            if isAutoPaused { applyAutoPauseIfNeeded() }
            return
        }

        if afkDetector.isUserAFK() {
            if !isAFK {
                isAFK = true
                closeCurrentSegment(at: afkDetector.lastInputDate())
            }
            resetRestReminder()
            syncStatistics()
            return
        }

        if isAFK {
            isAFK = false
            awaitingUserPresenceAfterWake = false
            beginNewSegment(force: true)
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        let appName = frontApp.localizedName ?? frontApp.bundleIdentifier ?? "Unknown"
        let bundleID = frontApp.bundleIdentifier ?? ""
        if Self.isNonTrackableApp(appName) {
            if currentSegment != nil {
                closeCurrentSegment()
            }
            resetNudgeStreak()
            resetRestReminder()
            syncStatistics()
            return
        }
        let rawTitle = windowExtractor.activeWindowTitle(for: frontApp)
        let sanitized = SensitiveWindowMasking.sanitize(appName: appName, windowTitle: rawTitle)
        let windowTitle = sanitized.windowTitle
        let category = classifier.classify(
            appName: appName,
            windowTitle: windowTitle,
            customRules: customRules
        )

        if appName != currentAppName || windowTitle != currentWindowTitle {
            closeCurrentSegment()
            currentAppName = appName
            currentBundleIdentifier = bundleID
            currentWindowTitle = windowTitle
            currentCategory = category
            beginNewSegment(force: false)
        } else if category != currentCategory {
            closeCurrentSegment()
            currentCategory = category
            beginNewSegment(force: false)
        }

        evaluateDistractionNudge()
        evaluateRestReminder()
        applyAutoPauseIfNeeded()
        syncStatistics()
    }

    // MARK: - Distraction Nudge (Feature)

    /// 비집중 카테고리에 임계 시간 이상 연속으로 머무르면 1회 알림을 보낸다.
    private func evaluateDistractionNudge() {
        guard DistractionNudgeStore.isEnabled, isTracking, !isAFK, !isPausedForPomodoroBreak else {
            resetNudgeStreak()
            return
        }

        if currentCategory.isFocusCategory {
            resetNudgeStreak()
            return
        }

        let now = Date()
        if nonFocusStreakStart == nil {
            nonFocusStreakStart = now
            nudgedCurrentStreak = false
        }

        guard let start = nonFocusStreakStart, !nudgedCurrentStreak else { return }
        guard now.timeIntervalSince(start) >= DistractionNudgeStore.thresholdSeconds else { return }

        // 과도한 반복 방지: 직전 알림 이후 임계 시간 이상 지났을 때만
        if let last = lastNudgeAt, now.timeIntervalSince(last) < DistractionNudgeStore.thresholdSeconds {
            nudgedCurrentStreak = true
            return
        }

        nudgedCurrentStreak = true
        lastNudgeAt = now
        sendDistractionNudge()
    }

    private func resetNudgeStreak() {
        nonFocusStreakStart = nil
        nudgedCurrentStreak = false
    }

    private func resetRestReminder() {
        continuousFocusStart = nil
        restNudgeSentForSession = false
    }

    private func evaluateRestReminder() {
        guard RestReminderStore.isEnabled, isTracking, !isAFK, !isPausedForPomodoroBreak, !isAutoPaused else {
            resetRestReminder()
            return
        }

        if currentCategory.isFocusCategory {
            if continuousFocusStart == nil { continuousFocusStart = Date() }
            guard let start = continuousFocusStart, !restNudgeSentForSession else { return }
            if Date().timeIntervalSince(start) >= RestReminderStore.thresholdSeconds {
                restNudgeSentForSession = true
                sendRestReminder()
            }
        } else {
            resetRestReminder()
        }
    }

    private func sendRestReminder() {
        let goal = FocusGoalStore.currentGoal
        let content = UNMutableNotificationContent()
        content.title = "잠깐, 눈을 쉬어요"
        content.body = goal.isEmpty
            ? "오래 집중하고 있어요. 20초만 멀리 바라볼까요?"
            : "오래 집중 중이에요. 목표 '\(goal)' — 잠깐 스트레칭 어때요?"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "lifelogger.rest.reminder", content: content, trigger: nil)
        )
    }

    private func sendDistractionNudge() {
        let minutes = DistractionNudgeStore.thresholdMinutes
        let categoryName = currentCategory.rawValue
        let goal = FocusGoalStore.currentGoal

        let content = UNMutableNotificationContent()
        content.title = "잠깐, 집중 흐름 체크"
        if goal.isEmpty {
            content.body = "\(categoryName)에 \(minutes)분 넘게 머물고 있어요. 다시 집중으로 돌아올까요?"
        } else {
            content.body = "\(minutes)분째 \(categoryName) 중이에요. 오늘 목표: \(goal)"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "lifelogger.distraction.nudge",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Segment Lifecycle

    private func beginNewSegment(force: Bool, at startTime: Date = Date()) {
        guard isTracking, !isPausedForPomodoroBreak, !isAFK, !awaitingUserPresenceAfterWake else { return }
        if let existing = currentSegment {
            if force {
                closeCurrentSegment(at: startTime)
            } else {
                return
            }
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let appName = frontApp.localizedName ?? frontApp.bundleIdentifier ?? "Unknown"
        let bundleID = frontApp.bundleIdentifier ?? ""
        guard !Self.isNonTrackableApp(appName) else { return }
        let rawTitle = windowExtractor.activeWindowTitle(for: frontApp)
        let sanitized = SensitiveWindowMasking.sanitize(appName: appName, windowTitle: rawTitle)
        let windowTitle = sanitized.windowTitle
        let category = classifier.classify(
            appName: appName,
            windowTitle: windowTitle,
            customRules: customRules
        )

        currentAppName = appName
        currentBundleIdentifier = bundleID
        currentWindowTitle = windowTitle
        currentCategory = category
        currentSegmentStart = startTime

        let segment = ActivitySegment(
            appName: appName,
            windowTitle: windowTitle,
            category: category,
            startTime: startTime
        )
        modelContext.insert(segment)
        currentSegment = segment
        persistSecurely()
    }

    private func closeCurrentSegment(at endTime: Date = Date()) {
        guard let segment = currentSegment else { return }
        segment.endTime = endTime
        currentSegment = nil
        currentSegmentStart = nil
        persistSecurely()
    }

    private func persistSecurely() {
        do {
            try modelContext.save()
            SecurityBootstrap.runAfterPersistenceWrite()
        } catch {
            AppLogger.persistence.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private func loadCustomRules() {
        let store = CategoryMappingStore(modelContext: modelContext)
        customRules = store.fetchAllRules()
    }

    private func restoreTrackingStateFromAppGroup() {
        let defaults = AppGroupConstants.sharedDefaults
        if defaults.object(forKey: AppGroupConstants.Keys.isTrackingEnabled) == nil {
            startTracking()
            return
        }
        if defaults.bool(forKey: AppGroupConstants.Keys.isTrackingEnabled) {
            startTracking()
        }
    }

    private func syncTrackingStateFromAppGroupIfNeeded() {
        let enabled = AppGroupConstants.sharedDefaults.bool(forKey: AppGroupConstants.Keys.isTrackingEnabled)
        if enabled != isTracking {
            if enabled {
                startTracking()
            } else {
                stopTracking()
            }
        }
    }

    private func syncStatistics(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastStatisticsSync) >= statisticsSyncInterval else { return }
        lastStatisticsSync = now

        let summary = statisticsEngine.summary()
        todayFocusRatio = summary.focusRatio
        refreshPublishedScreenOnSeconds()
        statisticsEngine.syncSharedStatistics(
            isTrackingEnabled: isTracking && !isPausedForPomodoroBreak,
            currentAppName: currentAppName.isEmpty ? nil : currentAppName,
            currentSegmentStart: currentSegmentStart
        )
        WidgetSyncHelper.reloadAllWidgets()
    }

    // MARK: - Screen-on time

    private func loadScreenOnPersistedTotal() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let saved = defaults.object(forKey: Self.screenOnDayKey) as? Date,
           calendar.isDate(saved, inSameDayAs: today) {
            screenOnAccumulated = defaults.double(forKey: Self.screenOnSecondsKey)
        } else {
            screenOnAccumulated = 0
            persistScreenOnTotal()
        }
    }

    private func persistScreenOnTotal() {
        UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: Self.screenOnDayKey)
        UserDefaults.standard.set(screenOnAccumulated, forKey: Self.screenOnSecondsKey)
    }

    private func beginScreenOnSession(at date: Date) {
        guard !isScreenOn else { return }
        isScreenOn = true
        screenOnSessionStart = date
        refreshPublishedScreenOnSeconds()
    }

    private func endScreenOnSession(at date: Date) {
        guard isScreenOn else { return }
        if let start = screenOnSessionStart {
            screenOnAccumulated += max(0, date.timeIntervalSince(start))
        }
        screenOnSessionStart = nil
        isScreenOn = false
        persistScreenOnTotal()
        refreshPublishedScreenOnSeconds()
    }

    private func refreshPublishedScreenOnSeconds() {
        rolloverScreenOnDayIfNeeded()
        var total = screenOnAccumulated
        if isScreenOn, let start = screenOnSessionStart {
            total += Date().timeIntervalSince(start)
        }
        todayScreenOnSeconds = total
    }

    private func rolloverScreenOnDayIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        guard let savedDay = UserDefaults.standard.object(forKey: Self.screenOnDayKey) as? Date,
              !calendar.isDate(savedDay, inSameDayAs: now) else { return }

        screenOnAccumulated = 0
        persistScreenOnTotal()
        if isScreenOn {
            screenOnSessionStart = calendar.startOfDay(for: now)
        }
    }

    private func startScreenOnTickTimer() {
        screenOnTickTimer?.invalidate()
        screenOnTickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPublishedScreenOnSeconds() }
        }
        if let screenOnTickTimer {
            RunLoop.main.add(screenOnTickTimer, forMode: .common)
        }
    }

    /// 잠금·로그인·스크린세이버 등 — 집중 시간에 포함하지 않는다.
    private static func isNonTrackableApp(_ appName: String) -> Bool {
        let lower = appName.lowercased()
        let blocked = [
            "loginwindow", "screensaverengine", "securityagent",
            "usernotificationcenter", "windowserver", "coreservicesuiagent"
        ]
        return blocked.contains { lower.contains($0) }
    }
}
