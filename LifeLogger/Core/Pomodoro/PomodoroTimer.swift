import Foundation
import UserNotifications

enum PomodoroPhase: String, Codable, Sendable {
    case idle
    case focus
    case shortBreak
    case longBreak

    var displayName: String {
        switch self {
        case .idle: return "대기"
        case .focus: return "집중"
        case .shortBreak: return "휴식"
        case .longBreak: return "긴 휴식"
        }
    }
}

@MainActor
final class PomodoroTimer: ObservableObject {
    @Published private(set) var phase: PomodoroPhase = .idle
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var completedFocusSessions: Int = 0

    var focusDuration: TimeInterval = 25 * 60
    var shortBreakDuration: TimeInterval = 5 * 60
    var longBreakDuration: TimeInterval = 15 * 60
    var sessionsBeforeLongBreak: Int = 4

    private var timer: Timer?
    private weak var activityTracker: ActivityTracker?

    init(activityTracker: ActivityTracker? = nil) {
        self.activityTracker = activityTracker
    }

    func attach(tracker: ActivityTracker) {
        activityTracker = tracker
    }

    func startFocus() {
        startPhase(.focus, duration: focusDuration)
        activityTracker?.resumeFromPomodoroBreak()
    }

    func start() {
        if phase == .idle {
            startFocus()
        }
    }

    /// 글로벌 핫키용 — 실행 중이면 일시정지, 아니면 집중 시작
    func toggleStartStop() {
        if phase == .idle || (timer == nil && remainingSeconds == 0) {
            startFocus()
        } else if timer != nil {
            pause()
        } else {
            startFocus()
        }
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        syncToAppGroup()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        phase = .idle
        remainingSeconds = 0
        completedFocusSessions = 0
        activityTracker?.resumeFromPomodoroBreak()
        syncToAppGroup()
    }

    private func startPhase(_ newPhase: PomodoroPhase, duration: TimeInterval) {
        timer?.invalidate()
        phase = newPhase
        remainingSeconds = Int(duration)

        if newPhase == .shortBreak || newPhase == .longBreak {
            activityTracker?.pauseForPomodoroBreak()
        } else if newPhase == .focus {
            activityTracker?.resumeFromPomodoroBreak()
        }

        scheduleNotification(for: newPhase, after: duration)
        syncToAppGroup()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            advancePhase()
            return
        }
        remainingSeconds -= 1
        syncToAppGroup()
    }

    private func advancePhase() {
        switch phase {
        case .focus:
            completedFocusSessions += 1
            sendLocalNotification(
                title: "집중 완료!",
                body: "5분 휴식을 시작하세요."
            )
            if completedFocusSessions % sessionsBeforeLongBreak == 0 {
                startPhase(.longBreak, duration: longBreakDuration)
            } else {
                startPhase(.shortBreak, duration: shortBreakDuration)
            }
        case .shortBreak, .longBreak:
            sendLocalNotification(
                title: "휴식 종료",
                body: "다시 집중 시간을 시작합니다."
            )
            startPhase(.focus, duration: focusDuration)
        case .idle:
            break
        }
    }

    private func scheduleNotification(for phase: PomodoroPhase, after duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = "집중 시간 종료"
            content.body = "잘하셨어요! 휴식을 취하세요."
        case .shortBreak, .longBreak:
            content.title = "휴식 종료"
            content.body = "다시 집중해볼까요?"
        case .idle:
            return
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(
            identifier: "lifelogger.pomodoro.\(phase.rawValue)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func syncToAppGroup() {
        SecureAppGroupWriter.writePomodoro(phase: phase.rawValue, remainingSeconds: remainingSeconds)
    }
}
