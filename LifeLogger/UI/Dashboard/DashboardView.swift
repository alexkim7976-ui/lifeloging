import SwiftUI
import SwiftData
import AppKit

struct DashboardView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @EnvironmentObject private var tracker: ActivityTracker
    @EnvironmentObject private var localContext: LocalContextService
    @EnvironmentObject private var friendShare: FriendShareCoordinator
    @Environment(\.modelContext) private var modelContext

    @State private var summary = DailyFocusSummary(
        totalSeconds: 0,
        focusSeconds: 0,
        focusRatio: 0,
        categoryBreakdown: [:]
    )
    @State private var segments: [ActivitySegment] = []
    @State private var topApps: [AppUsage] = []
    @State private var goalMinutes = DailyFocusGoalStore.goalMinutes
    @State private var goalStreak = 0
    @State private var shareMessage: String?
    @State private var showShareAlert = false
    @State private var exportMessage: String?
    @State private var showExportAlert = false
    @State private var showWidgetGuide = false
    @State private var showWeeklyReport = false
    @State private var showHeatmap = false
    @State private var showLanguageSelection = false
    @State private var showOnboarding = false
    @State private var showFeatureRoadmap = false
    @State private var showCommandPalette = false
    @State private var focusGoal = FocusGoalStore.currentGoal
    @State private var lastHeavyRefresh = Date.distantPast
    @State private var liveNow = Date()

    @State private var heatmapDays: [FocusStatisticsEngine.HeatmapDay] = []
    @State private var deepWorkSessions: [FocusStatisticsEngine.DeepWorkSession] = []
    @State private var focusDepth = FocusStatisticsEngine.FocusDepthMetrics(score: 0, switchesPerHour: 0, focusRatio: 0)
    @State private var weekComparison = FocusStatisticsEngine.WeekComparison(
        thisWeekFocusRatio: 0, lastWeekFocusRatio: 0, ratioDeltaPoints: 0, categoryDeltas: []
    )
    @State private var hourlyFocus: [FocusStatisticsEngine.HourlyFocus] = []
    @State private var summaryExportMessage: String?
    @State private var showSummaryExportAlert = false

    @StateObject private var pomodoro = PomodoroTimer()

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 24) {
                    headerBar

                    if tracker.isAccessibilityDegraded {
                        accessibilityBanner
                    }

                    if friendShare.showIncomingShareDialog, let received = friendShare.receivedShare {
                        IncomingShareDialogView(
                            share: received,
                            senderName: L10n.tr("share.friendDefault"),
                            onRecord: { friendShare.acceptIncomingShare(senderName: L10n.tr("share.friendDefault")) },
                            onDismiss: { friendShare.dismissIncomingShare() }
                        )
                    }

                    CurrentActivityCardView(focusRatioToday: summary.focusRatio)

                    HStack(alignment: .top, spacing: 24) {
                        FocusRingView(screenOnSeconds: tracker.todayScreenOnSeconds)

                        VStack(spacing: 16) {
                            FeedbackCardView(
                                localContext: localContext,
                                focusRatio: summary.focusRatio,
                                totalHours: summary.totalSeconds,
                                focusHours: summary.focusSeconds
                            )
                            pomodoroCard
                        }
                    }

                    DailyGoalCardView(
                        focusSeconds: summary.focusSeconds,
                        streak: goalStreak,
                        goalMinutes: $goalMinutes
                    )
                    .onChange(of: goalMinutes) { _, _ in refreshData() }

                    ActivityTimelineView(segments: segments, referenceNow: liveNow)

                    HStack(alignment: .top, spacing: 24) {
                        TopAppsCardView(apps: topApps)
                        CategoryBarChartView(breakdown: summary.categoryBreakdown)
                    }

                    FocusHeatmapCardView(days: heatmapDays) { showHeatmap = true }

                    HStack(alignment: .top, spacing: 24) {
                        DeepWorkCardView(sessions: deepWorkSessions)
                        FocusDepthCardView(metrics: focusDepth)
                    }

                    HStack(alignment: .top, spacing: 24) {
                        WeekCompareCardView(comparison: weekComparison)
                        HourlyFocusCardView(hourly: hourlyFocus)
                    }

                    ProjectTrackingCardView()

                    MacFeaturesHubCardView()

                    JournalCardView()
                }
                .padding(28)
            }
        }
        .onAppear {
            pomodoro.attach(tracker: tracker)
            refreshData()
            if AppLanguageStore.shared.needsLanguageSelection {
                showLanguageSelection = true
            } else if !OnboardingStore.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            liveNow = tick
            refreshLiveData(now: tick)
        }
        .alert(L10n.tr("dashboard.share.alert"), isPresented: $showShareAlert) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(shareMessage ?? "")
        }
        .alert(L10n.tr("dashboard.export.alert"), isPresented: $showExportAlert) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
        .sheet(isPresented: $friendShare.isShareSheetPresented) {
            if let snapshot = friendShare.shareSheetSnapshot {
                FriendShareSheetView(snapshot: snapshot) { message in
                    shareMessage = message
                    showShareAlert = true
                }
            }
        }
        .sheet(isPresented: $friendShare.isMessageCenterPresented) {
            AppLanguageRoot {
                MessengerRootView()
                    .modelContainer(MessengerModelContainer.shared)
                    .environmentObject(friendShare)
                    .environmentObject(tracker)
                    .environmentObject(BloomieCloudAuthService.shared)
                    .environmentObject(BloomieCloudChatService.shared)
            }
        }
        .sheet(isPresented: $showWidgetGuide) {
            AppLanguageRoot {
                DesktopWidgetGuideView()
            }
        }
        .sheet(isPresented: $showWeeklyReport) {
            AppLanguageRoot {
                WeeklyReportView()
                    .environment(\.modelContext, modelContext)
            }
        }
        .sheet(isPresented: $showHeatmap) {
            AppLanguageRoot {
                FocusHeatmapSheetView(days: heatmapDays)
            }
        }
        .sheet(isPresented: $showLanguageSelection) {
            AppLanguageRoot {
                LanguageSelectionView(isRequired: true)
                    .interactiveDismissDisabled(true)
            }
        }
        .sheet(isPresented: $showOnboarding) {
            AppLanguageRoot {
                OnboardingView()
            }
        }
        .sheet(isPresented: $showFeatureRoadmap) {
            AppLanguageRoot {
                FeatureRoadmapView()
            }
        }
        .overlay {
            if showCommandPalette {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { showCommandPalette = false }

                    CommandPaletteView(
                        isPresented: $showCommandPalette,
                        actions: commandPaletteActions
                    )
                }
            }
        }
        .background {
            Button("") { showCommandPalette = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        }
        .alert(L10n.tr("dashboard.summaryCard.alert"), isPresented: $showSummaryExportAlert) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(summaryExportMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .lifeloggerOpenCommandPalette)) { _ in
            showCommandPalette = true
        }
        .id(languageStore.language.rawValue)
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LifeLogger")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                    .liquidGlassReadableText()
                Text(L10n.tr("dashboard.tagline"))
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    tracker.toggleTracking()
                } label: {
                    Label(
                        tracker.isTracking ? L10n.tr("dashboard.pomodoro.pause") : L10n.tr("dashboard.pomodoro.start"),
                        systemImage: tracker.isTracking ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(LiquidGlassPrimaryButtonStyle())

                Button { showWeeklyReport = true } label: {
                    Image(systemName: "chart.xyaxis.line")
                }
                .buttonStyle(LiquidGlassIconButtonStyle())
                .help(L10n.tr("dashboard.weeklyReport"))

                Menu {
                    Button(L10n.tr("dashboard.export.png")) { exportSummaryCard(toClipboard: false) }
                    Button(L10n.tr("dashboard.export.copy")) { exportSummaryCard(toClipboard: true) }
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 36, height: 36)
                .help(L10n.tr("dashboard.exportSummaryCard"))

                Menu {
                    ForEach(ActivityExportService.Format.allCases) { format in
                        Button("\(format.rawValue)로 내보내기") { exportData(format: format) }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 36, height: 36)
                .help(L10n.tr("dashboard.exportData"))

                Button { showWidgetGuide = true } label: {
                    Image(systemName: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(LiquidGlassIconButtonStyle())
                .help(L10n.tr("dashboard.toolbar.widget"))

                Button { showFeatureRoadmap = true } label: {
                    Image(systemName: "square.grid.3x3.fill")
                }
                .buttonStyle(LiquidGlassIconButtonStyle())
                .help(L10n.tr("dashboard.toolbar.features"))

                languageToolbarMenu
            }
        }
        .padding(22)
        .liquidGlassCard(strong: true)
    }

    private var commandPaletteActions: [CommandPaletteAction] {
        [
            CommandPaletteAction(
                id: "roadmap",
                title: L10n.tr("dashboard.command.openRoadmap"),
                systemImage: "square.grid.3x3.fill"
            ) { showFeatureRoadmap = true },
            CommandPaletteAction(
                id: "weekly",
                title: L10n.tr("dashboard.command.weeklyReport"),
                systemImage: "chart.xyaxis.line"
            ) { showWeeklyReport = true },
            CommandPaletteAction(
                id: "widget",
                title: L10n.tr("dashboard.command.widgetGuide"),
                systemImage: "rectangle.on.rectangle.angled"
            ) { showWidgetGuide = true },
            CommandPaletteAction(
                id: "tracking",
                title: L10n.tr("dashboard.command.toggleTracking"),
                systemImage: tracker.isTracking ? "pause.fill" : "play.fill"
            ) { tracker.toggleTracking() },
            CommandPaletteAction(
                id: "language",
                title: L10n.tr("dashboard.command.language"),
                systemImage: "globe"
            ) { showLanguageSelection = true }
        ]
    }

    private var languageToolbarMenu: some View {
        Menu {
            ForEach(AppLanguage.userSelectableCases) { language in
                Button {
                    AppLanguageStore.shared.setLanguage(language)
                } label: {
                    if languageStore.language == language {
                        Label(language.nativeName, systemImage: "checkmark")
                    } else {
                        Text(language.nativeName)
                    }
                }
            }

            Divider()

            Button {
                showLanguageSelection = true
            } label: {
                Label(L10n.tr("settings.language.chooseTitle"), systemImage: "globe")
            }
        } label: {
            Image(systemName: "globe")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 36, height: 36)
        .help(L10n.tr("dashboard.toolbar.language"))
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LiquidGlassStyle.statusPaused)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("dashboard.tracking.degraded"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.titleText)
            }
            Spacer()
            Button(L10n.tr("dashboard.accessibility.openSettings")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
                tracker.requestPermissions()
            }
            .buttonStyle(LiquidGlassSecondaryButtonStyle())
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 14)
    }

    private var pomodoroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LiquidGlassSectionHeader(title: L10n.tr("dashboard.pomodoro.title"), systemImage: "timer")
                Spacer()
                LiquidGlassBadge(text: pomodoro.phase.displayName)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("dashboard.pomodoro.goalLabel"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.secondaryText)

                TextField(L10n.tr("dashboard.pomodoro.placeholder"), text: $focusGoal)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .liquidGlassInsetPanel(cornerRadius: 10)
                    .onChange(of: focusGoal) { _, newValue in
                        FocusGoalStore.currentGoal = newValue
                    }
            }

            if !focusGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(focusGoal)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                    .liquidGlassReadableText()
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            } else {
                Text(L10n.tr("dashboard.goal.placeholder"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.tertiaryText)
            }

            if pomodoro.phase != .idle || pomodoro.remainingSeconds > 0 {
                Text(formatPomodoroTime(pomodoro.remainingSeconds))
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(LiquidGlassStyle.iceBlue)
            }

            HStack(spacing: 10) {
                Button(L10n.tr("dashboard.pomodoro.start")) { pomodoro.start() }
                    .buttonStyle(LiquidGlassPrimaryButtonStyle())
                Button(L10n.tr("dashboard.pomodoro.pause")) { pomodoro.pause() }
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
                Button(L10n.tr("dashboard.pomodoro.reset")) { pomodoro.reset() }
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
            }
        }
        .padding(22)
        .liquidGlassCard()
    }

    private func refreshData() {
        refreshLiveData()
        refreshHeavyDataIfNeeded()
    }

    private func refreshLiveData(now: Date = Date()) {
        let engine = FocusStatisticsEngine(modelContext: modelContext)
        summary = engine.summary(now: now)
        DockFocusBadge.update(focusRatio: summary.focusRatio)
        segments = engine.fetchSegments(for: Date(), now: now)
        topApps = engine.topApps(limit: 5, now: now)
        goalStreak = engine.focusGoalStreak(targetSeconds: DailyFocusGoalStore.goalSeconds)
    }

    private func refreshHeavyDataIfNeeded(now: Date = Date()) {
        guard now.timeIntervalSince(lastHeavyRefresh) >= 30 else { return }
        lastHeavyRefresh = now

        let engine = FocusStatisticsEngine(modelContext: modelContext)
        heatmapDays = engine.heatmapMetrics(days: 90)
        deepWorkSessions = engine.deepWorkSessions(now: now)
        focusDepth = engine.focusDepth(now: now)
        weekComparison = engine.weekOverWeekComparison()
        hourlyFocus = engine.hourlyFocusCurve(now: now)

        Task {
            let analyzer = GoldenTimeAnalyzer(modelContext: modelContext)
            await analyzer.scheduleWeeklyInsightNotification()
        }
    }

    private func exportSummaryCard(toClipboard: Bool) {
        let card = TodaySummaryCardView(
            focusRatio: summary.focusRatio,
            focusSeconds: summary.focusSeconds,
            topApps: topApps,
            deepWorkCount: deepWorkSessions.count,
            depthScore: focusDepth.score
        )
        if let message = SummaryCardExportService.saveOrCopy(view: card, toClipboard: toClipboard) {
            summaryExportMessage = message
            showSummaryExportAlert = true
        }
    }

    private func exportData(format: ActivityExportService.Format) {
        let engine = FocusStatisticsEngine(modelContext: modelContext)
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -90, to: calendar.startOfDay(for: end)) ?? end
        let exportSegments = engine.fetchSegments(in: DateInterval(start: start, end: end))

        switch ActivityExportService.export(segments: exportSegments, format: format) {
        case .saved(let name):
            exportMessage = L10n.tr("dashboard.export.success", name, exportSegments.count)
            showExportAlert = true
        case .failed(let reason):
            exportMessage = L10n.tr("dashboard.export.failed", reason)
            showExportAlert = true
        case .cancelled:
            break
        }
    }

    private func formatPomodoroTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
