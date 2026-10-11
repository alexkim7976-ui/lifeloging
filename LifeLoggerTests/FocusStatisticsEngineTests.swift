import XCTest
import SwiftData
@testable import LifeLogger

@MainActor
final class FocusStatisticsEngineTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var engine: FocusStatisticsEngine!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Schema(versionedSchema: LifeLoggerSchemaV1.self),
            migrationPlan: LifeLoggerMigrationPlan.self,
            configurations: config
        )
        context = ModelContext(container)
        engine = FocusStatisticsEngine(modelContext: context)
    }

    func testSegmentDurationCalculatorOverlap() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let dayStart = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let segmentStart = dayStart.addingTimeInterval(-3600)
        let segmentEnd = dayStart.addingTimeInterval(1800)
        let overlap = SegmentDurationCalculator.overlapDuration(
            segmentStart: segmentStart,
            segmentEnd: segmentEnd,
            dayStart: dayStart,
            dayEnd: dayEnd
        )
        XCTAssertEqual(overlap, 1800, accuracy: 0.1)
    }

    func testSummaryAttributesCrossMidnightSegmentToPreviousDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let midnight = nextDay

        let segment = ActivitySegment(
            appName: "Xcode",
            windowTitle: "Project",
            category: .coding,
            startTime: day.addingTimeInterval(22 * 3600),
            endTime: midnight.addingTimeInterval(2 * 3600)
        )
        context.insert(segment)
        try context.save()

        let yesterdaySummary = engine.summary(for: day, calendar: calendar, now: midnight.addingTimeInterval(3 * 3600))
        XCTAssertEqual(yesterdaySummary.totalSeconds, 7200, accuracy: 1)

        let todaySummary = engine.summary(for: nextDay, calendar: calendar, now: midnight.addingTimeInterval(3 * 3600))
        XCTAssertEqual(todaySummary.totalSeconds, 7200, accuracy: 1)
    }

    func testDeepWorkMergesFocusBlocks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

        let s1 = ActivitySegment(
            appName: "Xcode", windowTitle: "A", category: .coding,
            startTime: day.addingTimeInterval(3600), endTime: day.addingTimeInterval(4200)
        )
        let s2 = ActivitySegment(
            appName: "Xcode", windowTitle: "B", category: .coding,
            startTime: day.addingTimeInterval(4300), endTime: day.addingTimeInterval(6000)
        )
        context.insert(s1)
        context.insert(s2)
        try context.save()

        let sessions = engine.deepWorkSessions(for: day, calendar: calendar, now: day.addingTimeInterval(8000))
        XCTAssertEqual(sessions.count, 1)
        XCTAssertGreaterThanOrEqual(sessions[0].duration, 25 * 60)
    }

    func testOrphanedOpenSegmentsDoNotInflateTodayTotal() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let now = day.addingTimeInterval(4 * 3600)

        for minute in 0..<120 {
            let start = day.addingTimeInterval(TimeInterval(minute * 60))
            let seg = ActivitySegment(
                appName: "App",
                windowTitle: "W",
                category: .coding,
                startTime: start,
                endTime: minute == 119 ? nil : start.addingTimeInterval(60)
            )
            context.insert(seg)
        }
        try context.save()

        let summary = engine.summary(for: day, calendar: calendar, now: now)
        XCTAssertLessThan(summary.totalSeconds, 4 * 3600 + 120)
    }

    func testFocusGoalStreak() throws {
        DailyFocusGoalStore.goalMinutes = 60
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = calendar.startOfDay(for: Date())

        for offset in 1...3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let seg = ActivitySegment(
                appName: "App", windowTitle: "W", category: .coding,
                startTime: day, endTime: day.addingTimeInterval(3700)
            )
            context.insert(seg)
        }
        try context.save()

        let streak = engine.focusGoalStreak(targetSeconds: 3600, calendar: calendar)
        XCTAssertGreaterThanOrEqual(streak, 3)
    }

    func testLockScreenInflatedSegmentIsRepaired() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.startOfDay(for: Date())

        let coding = ActivitySegment(
            appName: "Cursor",
            windowTitle: "Project",
            category: .coding,
            startTime: day.addingTimeInterval(3600),
            endTime: day.addingTimeInterval(7200)
        )
        let lock = ActivitySegment(
            appName: "loginwindow",
            windowTitle: "",
            category: .other,
            startTime: day.addingTimeInterval(5400),
            endTime: day.addingTimeInterval(6000)
        )
        context.insert(coding)
        context.insert(lock)
        try context.save()

        _ = engine.repairLockScreenInflatedSegments()
        try context.save()

        XCTAssertEqual(coding.endTime, lock.startTime)
        let summary = engine.summary(for: day, calendar: calendar, now: day.addingTimeInterval(8000))
        XCTAssertLessThan(summary.focusSeconds, 3600)
    }

    func testExcludedAppsAreNotCountedInSummary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

        let lock = ActivitySegment(
            appName: "loginwindow",
            windowTitle: "",
            category: .other,
            startTime: day.addingTimeInterval(3600),
            endTime: day.addingTimeInterval(7200)
        )
        context.insert(lock)
        try context.save()

        let summary = engine.summary(for: day, calendar: calendar, now: day.addingTimeInterval(8000))
        XCTAssertEqual(summary.totalSeconds, 0, accuracy: 0.1)
    }
}

final class SegmentDurationCalculatorTests: XCTestCase {
    func testDSTSpringForwardDayBounds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var components = DateComponents(year: 2024, month: 3, day: 10)
        let day = calendar.date(from: components)!
        let bounds = SegmentDurationCalculator.dayBounds(for: day, calendar: calendar)
        XCTAssertNotNil(bounds)
        let hours = bounds!.end.timeIntervalSince(bounds!.start) / 3600
        XCTAssertEqual(hours, 23, accuracy: 0.1)
    }
}
