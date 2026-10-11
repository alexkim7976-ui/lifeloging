import Foundation
import SwiftData
import UserNotifications

struct GoldenTimeInsight: Sendable {
    var bestWeekday: Int
    var bestHour: Int
    var successProbability: Double
    var weekdayName: String
}

/// 로컬 DB 기반 몰입 골든타임 분석 — 서버 통신 없음.
@MainActor
final class GoldenTimeAnalyzer {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func analyze(lastDays: Int = 30, calendar: Calendar = .current) -> GoldenTimeInsight? {
        let end = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -lastDays, to: end) else { return nil }

        let predicate = #Predicate<ActivitySegment> { segment in
            segment.startTime >= start && segment.isAFK == false
        }
        let descriptor = FetchDescriptor<ActivitySegment>(predicate: predicate)
        guard let segments = try? modelContext.fetch(descriptor), !segments.isEmpty else {
            return nil
        }

        var weekdayHourFocus: [String: (focus: TimeInterval, total: TimeInterval)] = [:]

        for segment in segments {
            let weekday = calendar.component(.weekday, from: segment.startTime)
            let hour = calendar.component(.hour, from: segment.startTime)
            let key = "\(weekday)-\(hour)"
            var entry = weekdayHourFocus[key, default: (0, 0)]
            entry.total += segment.duration
            if segment.category.isFocusCategory {
                entry.focus += segment.duration
            }
            weekdayHourFocus[key] = entry
        }

        guard let best = weekdayHourFocus.max(by: { lhs, rhs in
            let lhsRatio = lhs.value.total > 0 ? lhs.value.focus / lhs.value.total : 0
            let rhsRatio = rhs.value.total > 0 ? rhs.value.focus / rhs.value.total : 0
            return lhsRatio < rhsRatio
        }) else { return nil }

        let parts = best.key.split(separator: "-")
        guard parts.count == 2,
              let weekday = Int(parts[0]),
              let hour = Int(parts[1]) else { return nil }

        let ratio = best.value.total > 0 ? best.value.focus / best.value.total : 0
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        let weekdayName = formatter.weekdaySymbols[weekday - 1]

        return GoldenTimeInsight(
            bestWeekday: weekday,
            bestHour: hour,
            successProbability: ratio,
            weekdayName: weekdayName
        )
    }

    func scheduleWeeklyInsightNotification(calendar: Calendar = .current) async {
        guard let insight = analyze(calendar: calendar) else { return }

        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        guard granted == true else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["lifelogger.golden.time"])

        var components = DateComponents()
        components.weekday = insight.bestWeekday
        components.hour = max(0, insight.bestHour - 1)
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "몰입 골든타임 알림"
        content.body = "\(insight.weekdayName) \(insight.bestHour)시 전후가 가장 집중하기 좋은 시간이에요. (성공 확률 \(Int(insight.successProbability * 100))%)"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "lifelogger.golden.time",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}
