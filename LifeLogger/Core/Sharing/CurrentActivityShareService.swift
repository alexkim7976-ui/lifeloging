import Foundation
import AppKit

/// 사용자가 정한 오늘의 집중 목표 (로컬 저장)
enum FocusGoalStore {
    private static let key = "lifelogger.focusGoal"
    private static let maxLength = 120

    static var currentGoal: String {
        get {
            SecureInputValidator.sanitizeText(
                UserDefaults.standard.string(forKey: key) ?? "",
                maxLength: maxLength
            )
        }
        set {
            let sanitized = SecureInputValidator.sanitizeText(newValue, maxLength: maxLength)
            if sanitized.isEmpty {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(sanitized, forKey: key)
            }
        }
    }

    static var hasGoal: Bool {
        !currentGoal.isEmpty
    }
}

/// 하루 집중 목표 시간(분) — 로컬 저장. Streak/진행률 카드에서 사용.
enum DailyFocusGoalStore {
    private static let key = "lifelogger.dailyFocusGoalMinutes"
    static let defaultMinutes = 120
    static let options = [60, 90, 120, 180, 240, 300, 360]

    static var goalMinutes: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: key)
            return value > 0 ? value : defaultMinutes
        }
        set {
            let clamped = min(max(newValue, 15), 16 * 60)
            UserDefaults.standard.set(clamped, forKey: key)
        }
    }

    static var goalSeconds: TimeInterval { TimeInterval(goalMinutes * 60) }

    static func label(forMinutes minutes: Int) -> String {
        if minutes % 60 == 0 { return "\(minutes / 60)시간" }
        return "\(minutes / 60)시간 \(minutes % 60)분"
    }

    /// 프리셋 버튼용 짧은 라벨
    static func shortLabel(forMinutes minutes: Int) -> String {
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// 집중 이탈 넛지 알림 설정 — 로컬 저장, 기본 비활성.
enum DistractionNudgeStore {
    private static let enabledKey = "lifelogger.nudge.enabled"
    private static let minutesKey = "lifelogger.nudge.minutes"
    static let defaultMinutes = 15

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var thresholdMinutes: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: minutesKey)
            return value > 0 ? value : defaultMinutes
        }
        set { UserDefaults.standard.set(min(max(newValue, 5), 60), forKey: minutesKey) }
    }

    static var thresholdSeconds: TimeInterval { TimeInterval(thresholdMinutes * 60) }
}

// MARK: - Feature Stores (#8–#13, #16–#19)

enum RestReminderStore {
    private static let enabledKey = "lifelogger.rest.enabled"
    private static let minutesKey = "lifelogger.rest.minutes"
    static let defaultMinutes = 50

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var thresholdMinutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: minutesKey)
            return v > 0 ? v : defaultMinutes
        }
        set { UserDefaults.standard.set(min(max(newValue, 20), 90), forKey: minutesKey) }
    }

    static var thresholdSeconds: TimeInterval { TimeInterval(thresholdMinutes * 60) }
}

enum RetentionPolicyStore {
    private static let enabledKey = "lifelogger.retention.enabled"
    private static let daysKey = "lifelogger.retention.days"
    private static let lastRunKey = "lifelogger.retention.lastRun"
    static let defaultDays = 90

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var retentionDays: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: daysKey)
            return v > 0 ? v : defaultDays
        }
        set { UserDefaults.standard.set(min(max(newValue, 30), 365), forKey: daysKey) }
    }

    static var lastRunDate: Date? {
        get { UserDefaults.standard.object(forKey: lastRunKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastRunKey) }
    }
}

enum AutoPauseRuleStore {
    private static let appsKey = "lifelogger.autopause.apps"
    private static let rangesKey = "lifelogger.autopause.ranges"

    struct TimeRange: Codable, Sendable, Identifiable {
        var id: String { "\(startHour):\(startMinute)-\(endHour):\(endMinute)" }
        var startHour: Int
        var startMinute: Int
        var endHour: Int
        var endMinute: Int
    }

    static var pausedAppNames: [String] {
        get { UserDefaults.standard.stringArray(forKey: appsKey) ?? [] }
        set { UserDefaults.standard.set(SecureInputValidator.sanitizeAppNameList(newValue), forKey: appsKey) }
    }

    static var timeRanges: [TimeRange] {
        get {
            guard let data = UserDefaults.standard.data(forKey: rangesKey),
                  let decoded = try? JSONDecoder().decode([TimeRange].self, from: data) else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: rangesKey)
            }
        }
    }

    static func shouldAutoPause(appName: String, at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let name = appName.lowercased()
        if pausedAppNames.contains(where: { name.contains($0.lowercased()) || $0.lowercased().contains(name) }) {
            return true
        }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let nowMinutes = hour * 60 + minute
        for range in timeRanges {
            let start = range.startHour * 60 + range.startMinute
            let end = range.endHour * 60 + range.endMinute
            if start <= end {
                if nowMinutes >= start && nowMinutes < end { return true }
            } else if nowMinutes >= start || nowMinutes < end {
                return true
            }
        }
        return false
    }
}

enum GlobalHotkeyStore {
    private static let enabledKey = "lifelogger.hotkeys.enabled"
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}

enum OnboardingStore {
    private static let completedKey = "lifelogger.onboarding.completed"
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }
}

/// bloomie 메신저(클라우드) 사용 옵트인 — 활동 트래킹과 분리 (#3)
enum MessengerConsentStore {
    private static let key = "lifelogger.messenger.consent"

    static var hasConsented: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            AppLogger.privacy.info("Messenger cloud consent set to \(newValue, privacy: .public)")
        }
    }
}

enum FocusModeIntegrationStore {
    private static let enabledKey = "lifelogger.focusMode.enabled"
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}

enum JournalStore {
    private static let prefix = "lifelogger.journal."

    static func entry(for date: Date, calendar: Calendar = .current) -> String {
        let key = prefix + dayKey(date, calendar: calendar)
        return SecureInputValidator.sanitizeText(UserDefaults.standard.string(forKey: key) ?? "", maxLength: 500)
    }

    static func save(_ text: String, for date: Date, calendar: Calendar = .current) {
        let key = prefix + dayKey(date, calendar: calendar)
        let sanitized = SecureInputValidator.sanitizeText(text, maxLength: 500)
        if sanitized.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(sanitized, forKey: key)
        }
    }

    static func entries(lastDays: Int = 7, calendar: Calendar = .current) -> [(Date, String)] {
        (0..<lastDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date())) else { return nil }
            let text = entry(for: day, calendar: calendar)
            guard !text.isEmpty else { return nil }
            return (day, text)
        }
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = calendar
        return f.string(from: calendar.startOfDay(for: date))
    }
}

// MARK: - Global Hotkeys (#9)

@MainActor
final class GlobalHotkeyMonitor {
    private var trackingMonitor: Any?
    private var pomodoroMonitor: Any?
    private weak var tracker: ActivityTracker?
    private var pomodoroToggle: (() -> Void)?

    func start(tracker: ActivityTracker, pomodoroToggle: @escaping () -> Void) {
        guard GlobalHotkeyStore.isEnabled else { return }
        self.tracker = tracker
        self.pomodoroToggle = pomodoroToggle
        stop()

        trackingMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard GlobalHotkeyStore.isEnabled else { return }
            guard event.modifierFlags.contains([.control, .option]) else { return }
            Task { @MainActor in
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "l":
                    self?.tracker?.toggleTracking()
                case "p":
                    self?.pomodoroToggle?()
                default:
                    break
                }
            }
        }
    }

    func stop() {
        if let trackingMonitor {
            NSEvent.removeMonitor(trackingMonitor)
            self.trackingMonitor = nil
        }
    }
}

/// 현재 활동 스냅샷 — 히스토리 없이 지금 이 순간만 표현·공유
struct CurrentActivitySnapshot: Sendable {
    let appName: String
    let bundleIdentifier: String?
    let windowTitle: String
    let category: ActivityCategory
    let focusRatioToday: Double
    let segmentElapsedSeconds: Int
    let isTracking: Bool
    let isAFK: Bool
    let focusGoal: String

    var canShare: Bool {
        isTracking && !isAFK && !appName.isEmpty
    }

    var goalLabel: String? {
        let trimmed = focusGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var statusLabel: String {
        if !isTracking { return "일시정지" }
        if isAFK { return "자리 비움" }
        if appName.isEmpty { return "분석 중…" }
        return "진행 중"
    }

    var headline: String {
        if isAFK { return "자리 비움" }
        if appName.isEmpty { return "활동 감지 중…" }
        return appName
    }

    var subtitle: String {
        if isAFK { return "잠시 멀어져 있어요" }
        if windowTitle.isEmpty { return category.rawValue }
        return windowTitle
    }

    var elapsedLabel: String {
        let minutes = segmentElapsedSeconds / 60
        let seconds = segmentElapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var focusPercentLabel: String {
        "\(Int(min(max(focusRatioToday, 0), 1) * 100))%"
    }

    /// 노치 HUD 등 — 숫자 대신 짧은 한국어 상태 문구
    var elapsedHumanLabel: String {
        if !isTracking { return "멈춤" }
        if isAFK { return "자리 비움" }
        switch segmentElapsedSeconds {
        case ..<120: return "막 시작"
        case 120..<600: return "흐름 타는 중"
        case 600..<1800: return "몰입 중"
        case 1800..<3600: return "깊이 들어감"
        default: return "오래 이어짐"
        }
    }

    var focusMoodLabel: String {
        if !isTracking { return "일시정지" }
        if isAFK { return "쉬는 중" }
        switch min(max(focusRatioToday, 0), 1) {
        case 0.75...: return "몰입 흐름 좋음"
        case 0.55..<0.75: return "리듬 유지 중"
        case 0.35..<0.55: return "조금만 더"
        case 0.15..<0.35: return "가볍게 시작"
        default: return "천천히 가도 OK"
        }
    }
}

enum CurrentActivityShareService {
    @MainActor
    static func snapshot(from tracker: ActivityTracker, focusRatioToday: Double) -> CurrentActivitySnapshot {
        let elapsed: Int
        if let start = tracker.currentSegmentStart, tracker.isTracking, !tracker.isAFK {
            elapsed = max(0, Int(Date().timeIntervalSince(start)))
        } else {
            elapsed = 0
        }

        return CurrentActivitySnapshot(
            appName: SecureInputValidator.sanitizeAppName(tracker.currentAppName),
            bundleIdentifier: tracker.currentBundleIdentifier.isEmpty ? nil : tracker.currentBundleIdentifier,
            windowTitle: SecureInputValidator.sanitizeWindowTitle(tracker.currentWindowTitle),
            category: tracker.currentCategory,
            focusRatioToday: focusRatioToday,
            segmentElapsedSeconds: elapsed,
            isTracking: tracker.isTracking,
            isAFK: tracker.isAFK,
            focusGoal: FocusGoalStore.currentGoal
        )
    }

    static func buildShareText(_ snapshot: CurrentActivitySnapshot) -> String {
        guard snapshot.canShare else {
            return "지금 공유할 활동이 없습니다."
        }

        let windowLine = snapshot.windowTitle.isEmpty
            ? "작업: (제목 없음)"
            : "작업: \(snapshot.windowTitle)"

        var text = """
        📍 지금 하고 있는 일
        앱: \(snapshot.appName)
        \(windowLine)
        카테고리: \(snapshot.category.rawValue)
        이 활동: \(snapshot.elapsedLabel)
        오늘 집중: \(snapshot.focusPercentLabel)
        """

        if let goal = snapshot.goalLabel {
            text += "\n오늘 목표: \(goal)"
        }

        text += "\n\nLifeLogger에서 공유됨"
        return text
    }

    @MainActor
    static func copyToClipboard(_ snapshot: CurrentActivitySnapshot) -> Bool {
        guard snapshot.canShare else { return false }
        SecureClipboard.copyEphemeral(buildShareText(snapshot))
        return true
    }

    static func bloomiePayload(from snapshot: CurrentActivitySnapshot) -> BloomieShareHelper.SharePayload {
        BloomieShareHelper.SharePayload(
            appName: snapshot.appName,
            windowTitle: snapshot.windowTitle,
            category: snapshot.category,
            focusRatioToday: snapshot.focusRatioToday
        )
    }

    @MainActor
    static func shareViaBloomie(_ snapshot: CurrentActivitySnapshot) -> BloomieShareHelper.ShareResult {
        guard snapshot.canShare else {
            return .failed("공유할 활동이 없습니다.")
        }
        return BloomieShareHelper.shareCurrentActivity(bloomiePayload(from: snapshot))
    }

    static func bloomieShareMessage(for result: BloomieShareHelper.ShareResult) -> String {
        switch result {
        case .openedBloomie:
            return "bloomie로 현재 활동을 공유했습니다."
        case .copiedToClipboardFallback(let text):
            return "bloomie 앱을 찾을 수 없어 클립보드에 복사했습니다.\n\n\(text)"
        case .failed(let reason):
            return reason
        }
    }
}
