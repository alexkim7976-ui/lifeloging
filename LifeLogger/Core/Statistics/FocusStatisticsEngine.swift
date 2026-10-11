import Foundation
import SwiftData
import AppKit
import UniformTypeIdentifiers
import CryptoKit
import EventKit

struct DailyFocusSummary: Sendable {
    var totalSeconds: TimeInterval
    var focusSeconds: TimeInterval
    var focusRatio: Double
    var categoryBreakdown: [ActivityCategory: TimeInterval]
}

/// 앱 단위 사용량 — "오늘 많이 쓴 앱" 카드용.
struct AppUsage: Identifiable, Sendable {
    let appName: String
    let seconds: TimeInterval
    let category: ActivityCategory
    var id: String { appName }
}

/// 세그먼트와 캘린더 일자의 겹침 구간을 계산 (자정·DST·타임존 경계 대응).
enum SegmentDurationCalculator: Sendable {
    static func overlapDuration(
        segmentStart: Date,
        segmentEnd: Date,
        dayStart: Date,
        dayEnd: Date
    ) -> TimeInterval {
        let start = max(segmentStart, dayStart)
        let end = min(segmentEnd, dayEnd)
        return max(0, end.timeIntervalSince(start))
    }

    static func dayBounds(for date: Date, calendar: Calendar) -> (start: Date, end: Date)? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    static func effectiveEnd(for segment: ActivitySegment, now: Date = Date()) -> Date {
        segment.endTime ?? now
    }

    /// endTime이 nil인 세그먼트는 다음 세그먼트 시작 시각으로 닫음. 마지막만 now까지.
    static func resolvedEnds(for segments: [ActivitySegment], now: Date = Date()) -> [UUID: Date] {
        let sorted = segments.sorted { $0.startTime < $1.startTime }
        var ends: [UUID: Date] = [:]
        for (index, segment) in sorted.enumerated() {
            if let end = segment.endTime {
                ends[segment.id] = end
            } else if index + 1 < sorted.count {
                ends[segment.id] = max(segment.startTime, sorted[index + 1].startTime)
            } else {
                ends[segment.id] = now
            }
        }
        return ends
    }

    static func overlapsDay(
        segment: ActivitySegment,
        date: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard let bounds = dayBounds(for: date, calendar: calendar) else { return false }
        let segEnd = effectiveEnd(for: segment, now: now)
        return segment.startTime < bounds.end && segEnd > bounds.start
    }

    static func durationOnDay(
        segment: ActivitySegment,
        date: Date,
        calendar: Calendar = .current,
        now: Date = Date(),
        resolvedEnd: Date? = nil
    ) -> TimeInterval {
        guard let bounds = dayBounds(for: date, calendar: calendar) else { return 0 }
        let end = resolvedEnd ?? effectiveEnd(for: segment, now: now)
        return overlapDuration(
            segmentStart: segment.startTime,
            segmentEnd: end,
            dayStart: bounds.start,
            dayEnd: bounds.end
        )
    }
}

/// 통계에서 제외할 시스템·잠금 화면 앱.
enum SegmentStatisticsFilters: Sendable {
    private static let blockedSubstrings = [
        "loginwindow", "screensaverengine", "securityagent",
        "usernotificationcenter", "windowserver", "coreservicesuiagent"
    ]

    static func isExcluded(_ segment: ActivitySegment) -> Bool {
        let lower = segment.appName.lowercased()
        return blockedSubstrings.contains { lower.contains($0) }
    }
}

/// 시간 표시 공용 헬퍼 (예: 1시간 23분 / 12분).
@MainActor
enum DurationFormat {
    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 {
            return L10n.tr("duration.hoursMinutes", hours, minutes)
        }
        if hours > 0 { return L10n.tr("duration.hours", hours) }
        if minutes > 0 { return L10n.tr("duration.minutes", minutes) }
        return L10n.tr("duration.zeroMinutes")
    }

    static func ringDuration(_ seconds: TimeInterval) -> String {
        hoursMinutes(seconds)
    }
}

@MainActor
final class FocusStatisticsEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func summary(for date: Date = Date(), calendar: Calendar = .current, now: Date = Date()) -> DailyFocusSummary {
        let segments = fetchSegments(for: date, calendar: calendar, now: now)
        return computeSummary(from: segments, for: date, calendar: calendar, now: now)
    }

    func lastSevenDaysSummaries(endingOn date: Date = Date(), calendar: Calendar = .current) -> [DailyFocusSummary] {
        (0..<7).reversed().map { offset in
            let targetDate = calendar.date(byAdding: .day, value: -offset, to: date) ?? date
            return summary(for: targetDate, calendar: calendar)
        }
    }

    /// 지정일과 시간적으로 겹치는 세그먼트 (자정을 넘는 세그먼트 포함).
    func fetchSegments(for date: Date, calendar: Calendar = .current, now: Date = Date()) -> [ActivitySegment] {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let fetchStart = calendar.date(byAdding: .day, value: -1, to: dayStart) else { return [] }

        let predicate = #Predicate<ActivitySegment> { segment in
            segment.startTime >= fetchStart && segment.startTime < dayEnd && segment.isAFK == false
        }
        let descriptor = FetchDescriptor<ActivitySegment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        return candidates.filter {
            !SegmentStatisticsFilters.isExcluded($0)
                && SegmentDurationCalculator.overlapsDay(segment: $0, date: date, calendar: calendar, now: now)
        }
    }

    func computeSummary(
        from segments: [ActivitySegment],
        for date: Date? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> DailyFocusSummary {
        var total: TimeInterval = 0
        var focus: TimeInterval = 0
        var breakdown: [ActivityCategory: TimeInterval] = [:]
        let resolved = date != nil ? SegmentDurationCalculator.resolvedEnds(for: segments, now: now) : [:]

        for segment in segments {
            let duration: TimeInterval
            if let date {
                duration = SegmentDurationCalculator.durationOnDay(
                    segment: segment,
                    date: date,
                    calendar: calendar,
                    now: now,
                    resolvedEnd: resolved[segment.id]
                )
            } else {
                duration = segment.duration
            }
            guard duration > 0 else { continue }
            total += duration
            if segment.effectiveCategory.isFocusCategory {
                focus += duration
            }
            breakdown[segment.effectiveCategory, default: 0] += duration
        }

        let ratio = total > 0 ? focus / total : 0
        return DailyFocusSummary(
            totalSeconds: total,
            focusSeconds: focus,
            focusRatio: ratio,
            categoryBreakdown: breakdown
        )
    }

    /// endTime이 비어 있는 과거 세그먼트를 닫아 통계 부풀림을 방지 (#bugfix)
    @discardableResult
    func repairOrphanedOpenSegments(now: Date = Date()) -> Int {
        let predicate = #Predicate<ActivitySegment> { $0.endTime == nil && $0.isAFK == false }
        let descriptor = FetchDescriptor<ActivitySegment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )
        guard let open = try? modelContext.fetch(descriptor), !open.isEmpty else { return 0 }

        var repaired = 0

        for index in 0..<(open.count - 1) {
            let segment = open[index]
            let nextStart = open[index + 1].startTime
            segment.endTime = max(segment.startTime, nextStart)
            repaired += 1
        }

        if let lastOpen = open.last, lastOpen.endTime == nil {
            let lastStart = lastOpen.startTime
            var nextDescriptor = FetchDescriptor<ActivitySegment>(
                predicate: #Predicate<ActivitySegment> { segment in
                    segment.isAFK == false && segment.startTime > lastStart
                },
                sortBy: [SortDescriptor(\.startTime)]
            )
            nextDescriptor.fetchLimit = 1
            if let nextStart = try? modelContext.fetch(nextDescriptor).first?.startTime {
                lastOpen.endTime = max(lastOpen.startTime, nextStart)
                repaired += 1
            }
        }

        if repaired > 0 {
            try? modelContext.save()
            AppLogger.persistence.info("Repaired \(repaired, privacy: .public) orphaned open segments")
        }
        return repaired
    }

    /// 마지막 열린 세그먼트를 AFK 기준으로 닫아 노트북 방치 시간을 줄인다.
    @discardableResult
    func repairLastOpenSegmentUsingIdle(now: Date = Date()) -> Int {
        let predicate = #Predicate<ActivitySegment> { $0.endTime == nil && $0.isAFK == false }
        let descriptor = FetchDescriptor<ActivitySegment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        guard let lastOpen = try? modelContext.fetch(descriptor).first else { return 0 }

        let lastInput = AFKDetector().lastInputDate(at: now)
        let cappedEnd = max(lastOpen.startTime, min(now, lastInput))
        guard cappedEnd.timeIntervalSince(lastOpen.startTime) + 1 < now.timeIntervalSince(lastOpen.startTime) else {
            return 0
        }

        lastOpen.endTime = cappedEnd
        try? modelContext.save()
        AppLogger.persistence.info("Capped last open segment using idle input time")
        return 1
    }

    /// 잠금 화면(loginwindow) 직전까지로 과장된 세그먼트를 자른다.
    @discardableResult
    func repairLockScreenInflatedSegments(calendar: Calendar = .current) -> Int {
        guard let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) else { return 0 }
        let descriptor = FetchDescriptor<ActivitySegment>(
            predicate: #Predicate<ActivitySegment> { segment in
                segment.isAFK == false && segment.startTime >= cutoff
            },
            sortBy: [SortDescriptor(\.startTime)]
        )
        guard let segments = try? modelContext.fetch(descriptor), segments.count > 1 else { return 0 }

        var repaired = 0
        for index in 1..<segments.count {
            let current = segments[index]
            guard SegmentStatisticsFilters.isExcluded(current) else { continue }
            let previous = segments[index - 1]
            let lockStart = current.startTime
            let previousEnd = previous.endTime ?? lockStart
            if previousEnd > lockStart {
                previous.endTime = lockStart
                repaired += 1
            }
        }

        if repaired > 0 {
            try? modelContext.save()
            AppLogger.persistence.info("Repaired \(repaired, privacy: .public) lock-screen inflated segments")
        }
        return repaired
    }

    /// 앱 시작 시 한 번 호출 — 과거·현재 부풀린 기록을 정리한다.
    @discardableResult
    func repairInflatedSegments(now: Date = Date()) -> Int {
        repairLockScreenInflatedSegments()
            + repairOrphanedOpenSegments(now: now)
            + repairLastOpenSegmentUsingIdle(now: now)
    }

    // MARK: - Top Apps (Feature)

    /// 오늘(또는 지정일) 가장 오래 사용한 앱 Top N.
    func topApps(for date: Date = Date(), calendar: Calendar = .current, limit: Int = 5, now: Date = Date()) -> [AppUsage] {
        let segments = fetchSegments(for: date, calendar: calendar, now: now)
        let resolved = SegmentDurationCalculator.resolvedEnds(for: segments, now: now)
        var totals: [String: TimeInterval] = [:]
        var categoryTotals: [String: [ActivityCategory: TimeInterval]] = [:]

        for segment in segments {
            let duration = SegmentDurationCalculator.durationOnDay(
                segment: segment,
                date: date,
                calendar: calendar,
                now: now,
                resolvedEnd: resolved[segment.id]
            )
            guard duration > 0 else { continue }
            let name = segment.appName.isEmpty ? "알 수 없음" : segment.appName
            totals[name, default: 0] += duration
            categoryTotals[name, default: [:]][segment.effectiveCategory, default: 0] += duration
        }

        return totals
            .map { name, seconds -> AppUsage in
                let dominant = categoryTotals[name]?.max { $0.value < $1.value }?.key ?? .other
                return AppUsage(appName: name, seconds: seconds, category: dominant)
            }
            .filter { $0.seconds > 0 }
            .sorted { $0.seconds > $1.seconds }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Daily Goal Streak (Feature)

    /// 일일 집중 목표를 연속으로 달성한 일수. 오늘은 진행 중일 수 있으므로,
    /// 오늘이 아직 미달이면 어제부터 카운트해 연속 기록이 끊기지 않게 한다.
    func focusGoalStreak(targetSeconds: TimeInterval, calendar: Calendar = .current, maxLookback: Int = 180) -> Int {
        guard targetSeconds > 0 else { return 0 }
        var streak = 0
        var offset = 0

        if summary(for: Date(), calendar: calendar).focusSeconds < targetSeconds {
            offset = 1
        }

        while offset < maxLookback {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { break }
            if summary(for: day, calendar: calendar).focusSeconds >= targetSeconds {
                streak += 1
                offset += 1
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Range fetch (Export)

    func fetchSegments(in interval: DateInterval) -> [ActivitySegment] {
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<ActivitySegment> { segment in
            segment.startTime >= start && segment.startTime < end && segment.isAFK == false
        }
        let descriptor = FetchDescriptor<ActivitySegment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Heatmap (#1)

    struct HeatmapDay: Identifiable, Sendable {
        let date: Date
        let focusSeconds: TimeInterval
        let focusRatio: Double
        let level: Int
        var id: Date { date }
    }

    func heatmapMetrics(days: Int = 90, endingOn date: Date = Date(), calendar: Calendar = .current) -> [HeatmapDay] {
        guard days > 0 else { return [] }
        var maxFocus: TimeInterval = 1
        var summaries: [(Date, DailyFocusSummary)] = []

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date)) else { continue }
            let s = summary(for: day, calendar: calendar)
            summaries.append((day, s))
            maxFocus = max(maxFocus, s.focusSeconds)
        }

        return summaries.reversed().map { day, s in
            let level: Int
            if s.focusSeconds <= 0 {
                level = 0
            } else {
                let normalized = s.focusSeconds / maxFocus
                level = min(4, max(1, Int(ceil(normalized * 4))))
            }
            return HeatmapDay(date: day, focusSeconds: s.focusSeconds, focusRatio: s.focusRatio, level: level)
        }
    }

    // MARK: - Deep Work (#2)

    struct DeepWorkSession: Identifiable, Sendable {
        let start: Date
        let end: Date
        let duration: TimeInterval
        var id: Date { start }
    }

    struct DeepWorkConfig: Sendable {
        var minDuration: TimeInterval = 25 * 60
        var maxGap: TimeInterval = 2 * 60
    }

    func deepWorkSessions(
        for date: Date = Date(),
        calendar: Calendar = .current,
        config: DeepWorkConfig = DeepWorkConfig(),
        now: Date = Date()
    ) -> [DeepWorkSession] {
        guard let bounds = SegmentDurationCalculator.dayBounds(for: date, calendar: calendar) else { return [] }
        let segs = fetchSegments(for: date, calendar: calendar, now: now).sorted { $0.startTime < $1.startTime }
        let resolved = SegmentDurationCalculator.resolvedEnds(for: segs, now: now)
        var sessions: [DeepWorkSession] = []
        var blockStart: Date?
        var blockEnd: Date?

        func flush() {
            guard let start = blockStart, let end = blockEnd else { return }
            let duration = end.timeIntervalSince(start)
            if duration >= config.minDuration {
                sessions.append(DeepWorkSession(start: start, end: end, duration: duration))
            }
            blockStart = nil
            blockEnd = nil
        }

        for segment in segs {
            guard segment.effectiveCategory.isFocusCategory else {
                flush()
                continue
            }
            let segStart = max(segment.startTime, bounds.start)
            let segEnd = min(resolved[segment.id] ?? SegmentDurationCalculator.effectiveEnd(for: segment, now: now), bounds.end)
            guard segEnd > segStart else { continue }

            if let end = blockEnd, segStart.timeIntervalSince(end) > config.maxGap {
                flush()
            }

            if blockStart == nil {
                blockStart = segStart
            }
            blockEnd = max(blockEnd ?? segEnd, segEnd)
        }
        flush()
        return sessions
    }

    // MARK: - Focus Depth (#3)

    struct FocusDepthMetrics: Sendable {
        let score: Int
        let switchesPerHour: Double
        let focusRatio: Double
    }

    /// 집중 깊이 = 집중률(0~70점) − 전환 패널티(시간당 전환×8, 최대 30점)
    func focusDepth(for date: Date = Date(), calendar: Calendar = .current, now: Date = Date()) -> FocusDepthMetrics {
        let segs = fetchSegments(for: date, calendar: calendar, now: now)
        let s = computeSummary(from: segs, for: date, calendar: calendar, now: now)
        let hours = max(s.totalSeconds / 3600, 0.25)
        var switches = 0
        var lastApp = ""
        for seg in segs {
            if seg.appName != lastApp {
                if !lastApp.isEmpty { switches += 1 }
                lastApp = seg.appName
            }
        }
        let perHour = Double(switches) / hours
        let ratioPoints = Int(min(max(s.focusRatio, 0), 1) * 70)
        let penalty = Int(min(30, perHour * 8))
        let score = max(0, min(100, ratioPoints + (30 - penalty)))
        return FocusDepthMetrics(score: score, switchesPerHour: perHour, focusRatio: s.focusRatio)
    }

    // MARK: - Week Compare (#4)

    struct WeekComparison: Sendable {
        let thisWeekFocusRatio: Double
        let lastWeekFocusRatio: Double
        let ratioDeltaPoints: Double
        let categoryDeltas: [(ActivityCategory, TimeInterval)]
    }

    func weekOverWeekComparison(calendar: Calendar = .current) -> WeekComparison {
        func weekSummary(startOffset: Int) -> DailyFocusSummary {
            var total: TimeInterval = 0
            var focus: TimeInterval = 0
            var breakdown: [ActivityCategory: TimeInterval] = [:]
            for d in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: -(startOffset + d), to: Date()) else { continue }
                let s = summary(for: day, calendar: calendar)
                total += s.totalSeconds
                focus += s.focusSeconds
                for (cat, t) in s.categoryBreakdown {
                    breakdown[cat, default: 0] += t
                }
            }
            let ratio = total > 0 ? focus / total : 0
            return DailyFocusSummary(totalSeconds: total, focusSeconds: focus, focusRatio: ratio, categoryBreakdown: breakdown)
        }

        let thisWeek = weekSummary(startOffset: 0)
        let lastWeek = weekSummary(startOffset: 7)
        var deltas: [(ActivityCategory, TimeInterval)] = []
        for cat in ActivityCategory.allCases {
            let delta = (thisWeek.categoryBreakdown[cat] ?? 0) - (lastWeek.categoryBreakdown[cat] ?? 0)
            if abs(delta) > 60 { deltas.append((cat, delta)) }
        }
        deltas.sort { abs($0.1) > abs($1.1) }
        return WeekComparison(
            thisWeekFocusRatio: thisWeek.focusRatio,
            lastWeekFocusRatio: lastWeek.focusRatio,
            ratioDeltaPoints: (thisWeek.focusRatio - lastWeek.focusRatio) * 100,
            categoryDeltas: deltas
        )
    }

    // MARK: - Hourly Curve (#5)

    struct HourlyFocus: Identifiable, Sendable {
        let hour: Int
        let focusRatio: Double
        let focusMinutes: Double
        var id: Int { hour }
    }

    func hourlyFocusCurve(for date: Date = Date(), calendar: Calendar = .current, now: Date = Date()) -> [HourlyFocus] {
        let segs = fetchSegments(for: date, calendar: calendar, now: now)
        let resolved = SegmentDurationCalculator.resolvedEnds(for: segs, now: now)
        guard let bounds = SegmentDurationCalculator.dayBounds(for: date, calendar: calendar) else {
            return (0..<24).map { HourlyFocus(hour: $0, focusRatio: 0, focusMinutes: 0) }
        }
        var focusByHour = Array(repeating: TimeInterval(0), count: 24)
        var totalByHour = Array(repeating: TimeInterval(0), count: 24)

        for seg in segs {
            let segStart = max(seg.startTime, bounds.start)
            let segEnd = min(resolved[seg.id] ?? SegmentDurationCalculator.effectiveEnd(for: seg, now: now), bounds.end)
            guard segEnd > segStart else { continue }

            var cursor = segStart
            while cursor < segEnd {
                let hour = calendar.component(.hour, from: cursor)
                guard hour >= 0, hour < 24 else { break }
                guard let hourStart = calendar.date(
                    bySettingHour: hour, minute: 0, second: 0, of: bounds.start
                ), let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else { break }
                let sliceEnd = min(segEnd, hourEnd)
                let slice = max(0, sliceEnd.timeIntervalSince(max(cursor, hourStart)))
                totalByHour[hour] += slice
                if seg.effectiveCategory.isFocusCategory {
                    focusByHour[hour] += slice
                }
                cursor = hourEnd
            }
        }

        return (0..<24).map { h in
            let total = totalByHour[h]
            let focus = focusByHour[h]
            let ratio = total > 0 ? focus / total : 0
            return HourlyFocus(hour: h, focusRatio: ratio, focusMinutes: focus / 60)
        }
    }

    // MARK: - Projects (#7)

    struct ProjectStat: Identifiable, Sendable {
        let tag: String
        let focusSeconds: TimeInterval
        let totalSeconds: TimeInterval
        var focusRatio: Double { totalSeconds > 0 ? focusSeconds / totalSeconds : 0 }
        var id: String { tag }
    }

    func projectStats(days: Int = 7, calendar: Calendar = .current) -> [ProjectStat] {
        guard let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date())) else { return [] }
        let segs = fetchSegments(in: DateInterval(start: start, end: Date()))
        var totals: [String: (focus: TimeInterval, total: TimeInterval)] = [:]

        for seg in segs {
            guard let tag = seg.effectiveTag else { continue }
            var entry = totals[tag, default: (0, 0)]
            entry.total += seg.duration
            if seg.effectiveCategory.isFocusCategory { entry.focus += seg.duration }
            totals[tag] = entry
        }

        return totals.map { ProjectStat(tag: $0.key, focusSeconds: $0.value.focus, totalSeconds: $0.value.total) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    func allTags(calendar: Calendar = .current) -> [String] {
        guard let start = calendar.date(byAdding: .day, value: -365, to: Date()) else { return [] }
        let segs = fetchSegments(in: DateInterval(start: start, end: Date()))
        let tags = Set(segs.compactMap(\.effectiveTag))
        return tags.sorted()
    }

    // MARK: - Retention (#13)

    @discardableResult
    func purgeSegments(olderThan days: Int, calendar: Calendar = .current) -> Int {
        guard days > 0,
              let cutoff = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date())) else { return 0 }
        let predicate = #Predicate<ActivitySegment> { $0.startTime < cutoff }
        let descriptor = FetchDescriptor<ActivitySegment>(predicate: predicate)
        guard let old = try? modelContext.fetch(descriptor) else { return 0 }
        for seg in old { modelContext.delete(seg) }
        try? modelContext.save()
        return old.count
    }

    func syncSharedStatistics(isTrackingEnabled: Bool, currentAppName: String?, currentSegmentStart: Date?) {
        let today = summary()
        let week = lastSevenDaysSummaries()
        var stats = SharedStatistics(
            todayFocusRatio: today.focusRatio,
            todayTotalSeconds: today.totalSeconds,
            todayFocusSeconds: today.focusSeconds,
            lastSevenDayFocusRatios: week.map(\.focusRatio),
            isTrackingEnabled: isTrackingEnabled,
            currentAppName: currentAppName,
            currentSegmentStart: currentSegmentStart
        )
        stats.writeToAppGroup()
    }
}

// MARK: - Local Data Export (Feature)

/// 활동 기록을 사용자가 선택한 위치로 JSON / CSV 내보내기.
/// 클라우드 업로드 없음 — NSSavePanel로 로컬 파일에만 저장한다.
@MainActor
enum ActivityExportService {
    enum Format: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv = "CSV"
        var id: String { rawValue }
        var contentType: UTType { self == .json ? .json : .commaSeparatedText }
        var ext: String { self == .json ? "json" : "csv" }
    }

    enum Result {
        case saved(String)
        case cancelled
        case failed(String)
    }

    /// 저장 패널을 띄우고 결과를 반환한다.
    static func export(segments: [ActivitySegment], format: Format) -> Result {
        let data: Data
        switch format {
        case .json:
            data = jsonData(from: segments)
        case .csv:
            data = Data(csvString(from: segments).utf8)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let panel = NSSavePanel()
        panel.title = "LifeLogger 데이터 내보내기"
        panel.nameFieldStringValue = "LifeLogger-\(formatter.string(from: Date())).\(format.ext)"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return .cancelled
        }
        do {
            try data.write(to: url, options: .atomic)
            return .saved(url.lastPathComponent)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: Builders

    private struct ExportRow: Encodable {
        let app: String
        let window: String
        let category: String
        let isFocus: Bool
        let start: String
        let end: String
        let durationSeconds: Int
    }

    private static func rows(from segments: [ActivitySegment]) -> [ExportRow] {
        let iso = ISO8601DateFormatter()
        return segments.map { segment in
            ExportRow(
                app: SecureInputValidator.sanitizeAppName(segment.appName),
                window: SecureInputValidator.sanitizeWindowTitle(segment.windowTitle),
                category: segment.category.rawValue,
                isFocus: segment.category.isFocusCategory,
                start: iso.string(from: segment.startTime),
                end: segment.endTime.map { iso.string(from: $0) } ?? "",
                durationSeconds: Int(segment.duration)
            )
        }
    }

    private static func jsonData(from segments: [ActivitySegment]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(rows(from: segments))) ?? Data("[]".utf8)
    }

    private static func csvString(from segments: [ActivitySegment]) -> String {
        var lines = ["app,window,category,isFocus,start,end,durationSeconds"]
        for row in rows(from: segments) {
            let fields = [
                row.app, row.window, row.category, row.isFocus ? "true" : "false",
                row.start, row.end, String(row.durationSeconds)
            ]
            lines.append(fields.map(csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - Encrypted Backup (#12)

@MainActor
enum ActivityBackupService {
    enum Result {
        case saved(String)
        case imported(Int)
        case cancelled
        case failed(String)
    }

    struct BackupPayload: Codable {
        struct Row: Codable {
            let id: UUID
            let app: String
            let window: String
            let category: String
            let userCategory: String?
            let tag: String?
            let note: String?
            let isAFK: Bool
            let start: Date
            let end: Date?
        }
        let version: Int
        let exportedAt: Date
        let rows: [Row]
    }

    static func exportEncrypted(segments: [ActivitySegment], password: String) -> Result {
        guard !password.isEmpty else { return .failed("암호를 입력해주세요.") }
        let rows = segments.map { seg in
            BackupPayload.Row(
                id: seg.id,
                app: SecureInputValidator.sanitizeAppName(seg.appName),
                window: SecureInputValidator.sanitizeWindowTitle(seg.windowTitle),
                category: seg.categoryRaw,
                userCategory: seg.userCategoryRaw,
                tag: seg.tag,
                note: seg.note,
                isAFK: seg.isAFK,
                start: seg.startTime,
                end: seg.endTime
            )
        }
        let payload = BackupPayload(version: 1, exportedAt: Date(), rows: rows)
        guard let json = try? JSONEncoder().encode(payload) else { return .failed("백업 데이터 생성 실패") }
        guard let sealed = try? encrypt(data: json, password: password) else { return .failed("암호화 실패") }

        let panel = NSSavePanel()
        panel.title = "암호화 백업 저장"
        panel.nameFieldStringValue = "LifeLogger-backup.llbackup"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return .cancelled }
        do {
            try sealed.write(to: url, options: .atomic)
            return .saved(url.lastPathComponent)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func importEncrypted(context: ModelContext, merge: Bool) -> Result {
        let panel = NSOpenPanel()
        panel.title = "백업 불러오기"
        panel.allowedContentTypes = [.data]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return .cancelled }

        guard let data = try? Data(contentsOf: url) else { return .failed("파일을 읽을 수 없습니다.") }
        let password = promptPassword(message: "백업 암호를 입력하세요")
        guard let password, !password.isEmpty else { return .cancelled }
        guard let json = try? decrypt(data: data, password: password),
              let payload = try? JSONDecoder().decode(BackupPayload.self, from: json) else {
            return .failed("복호화 실패 — 암호를 확인해주세요.")
        }

        var imported = 0
        let existingIDs: Set<UUID>
        if merge {
            let all = (try? context.fetch(FetchDescriptor<ActivitySegment>())) ?? []
            existingIDs = Set(all.map(\.id))
        } else {
            let all = (try? context.fetch(FetchDescriptor<ActivitySegment>())) ?? []
            for seg in all { context.delete(seg) }
            existingIDs = []
        }

        for row in payload.rows {
            if existingIDs.contains(row.id) { continue }
            let cat = ActivityCategory(rawValue: row.category) ?? .other
            let seg = ActivitySegment(
                id: row.id,
                appName: row.app,
                windowTitle: row.window,
                category: cat,
                startTime: row.start,
                endTime: row.end,
                isAFK: row.isAFK,
                userCategoryRaw: row.userCategory,
                tag: row.tag,
                note: row.note
            )
            context.insert(seg)
            imported += 1
        }
        try? context.save()
        return .imported(imported)
    }

    private static func encrypt(data: Data, password: String) throws -> Data {
        let key = deriveKey(from: password)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw NSError(domain: "backup", code: 1) }
        return combined
    }

    private static func decrypt(data: Data, password: String) throws -> Data {
        let key = deriveKey(from: password)
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    private static func deriveKey(from password: String) -> SymmetricKey {
        let hash = SHA256.hash(data: Data(password.utf8))
        return SymmetricKey(data: hash)
    }

    private static func promptPassword(message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }
}

// MARK: - Calendar Overlay (#18)

@MainActor
enum CalendarOverlayService {
    static let store = EKEventStore()

    static func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    static func events(for date: Date, calendar: Calendar = .current) -> [EKEvent] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
}
