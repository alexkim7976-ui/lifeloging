import CoreGraphics
import Foundation

/// CGEventSource를 이용한 AFK(자리 비움) 감지기.
struct AFKDetector: Sendable {
    var idleThreshold: TimeInterval

    init(idleThreshold: TimeInterval = 90) {
        self.idleThreshold = idleThreshold
    }

    /// 마지막 입력 이후 경과 시간(초).
    nonisolated func secondsSinceLastInput() -> TimeInterval {
        let eventTypes: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
        let idles = eventTypes.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }
        return idles.min() ?? .infinity
    }

    /// AFK 판정 시 세그먼트를 닫을 실제 종료 시각 (마지막 입력 직후).
    nonisolated func lastInputDate(at reference: Date = Date()) -> Date {
        let idle = secondsSinceLastInput()
        guard idle.isFinite else { return reference }
        return reference.addingTimeInterval(-idle)
    }

    nonisolated func isUserAFK(at date: Date = Date()) -> Bool {
        _ = date
        return secondsSinceLastInput() >= idleThreshold
    }
}
