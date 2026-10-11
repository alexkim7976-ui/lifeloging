import SwiftUI
import SwiftData
import Charts
import AppKit
import UserNotifications

struct CategoryBarChartView: View {
    let breakdown: [ActivityCategory: TimeInterval]

    private var chartData: [(category: ActivityCategory, hours: Double)] {
        ActivityCategory.allCases.compactMap { category in
            guard let seconds = breakdown[category], seconds > 0 else { return nil }
            return (category, seconds / 3600)
        }
        .sorted { $0.hours > $1.hours }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiquidGlassSectionHeader(title: "카테고리별 시간", systemImage: "chart.bar.fill")

            if chartData.isEmpty {
                Text("데이터 수집 중...")
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Chart(chartData, id: \.category) { item in
                    BarMark(
                        x: .value("시간", item.hours),
                        y: .value("카테고리", item.category.rawValue)
                    )
                    .foregroundStyle(
                        item.category.isFocusCategory
                            ? LiquidGlassStyle.barChartFocusGradient
                            : LiquidGlassStyle.barChartMutedGradient
                    )
                    .cornerRadius(8)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel()
                            .foregroundStyle(LiquidGlassStyle.secondaryText)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(LiquidGlassStyle.bodyText)
                    }
                }
                .frame(height: CGFloat(chartData.count) * 38 + 44)
                .padding(12)
                .liquidGlassInsetPanel()
            }
        }
        .padding(22)
        .liquidGlassCard()
    }
}

// MARK: - Feature: 오늘 많이 쓴 앱 Top

struct TopAppsCardView: View {
    let apps: [AppUsage]

    private var maxSeconds: TimeInterval {
        max(apps.map(\.seconds).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiquidGlassSectionHeader(title: "오늘 많이 쓴 앱", systemImage: "square.stack.3d.up.fill")

            if apps.isEmpty {
                Text("데이터 수집 중...")
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        row(rank: index + 1, app: app)
                    }
                }
            }
        }
        .padding(22)
        .liquidGlassCard()
    }

    private func row(rank: Int, app: AppUsage) -> some View {
        let accent = Color(hex: app.category.accentHex) ?? LiquidGlassStyle.skyBlue
        let fraction = app.seconds / maxSeconds

        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
                .frame(width: 16, alignment: .center)

            Image(systemName: app.category.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(app.appName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                        .lineLimit(1)
                    Spacer()
                    Text(DurationFormat.hoursMinutes(app.seconds))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(LiquidGlassStyle.secondaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.95), accent.opacity(0.55)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * fraction))
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Feature: 주간 리포트 시트

struct WeeklyReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var dailyRatios: [(day: String, ratio: Double, focusSeconds: TimeInterval)] = []
    @State private var weekFocusSeconds: TimeInterval = 0
    @State private var averageRatio: Double = 0
    @State private var goldenInsight: GoldenTimeInsight?
    @State private var bestDayLabel: String = "—"
    @State private var weekComparison = FocusStatisticsEngine.WeekComparison(
        thisWeekFocusRatio: 0, lastWeekFocusRatio: 0, ratioDeltaPoints: 0, categoryDeltas: []
    )
    @State private var journalEntries: [(Date, String)] = []

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    summaryRow
                    WeekCompareCardView(comparison: weekComparison)
                    trendCard
                    journalSection
                    if let insight = goldenInsight {
                        goldenCard(insight)
                    }
                }
                .padding(28)
            }
        }
        .frame(minWidth: 520, minHeight: 560)
        .onAppear(perform: compute)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("주간 리포트")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                    .liquidGlassReadableText()
                Text("최근 7일 몰입 흐름 회고")
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            }
            Spacer()
            Button("닫기") { dismiss() }
                .buttonStyle(LiquidGlassSecondaryButtonStyle())
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 16) {
            metric(title: "주간 집중", value: DurationFormat.hoursMinutes(weekFocusSeconds))
            metric(title: "평균 집중률", value: "\(Int(averageRatio * 100))%")
            metric(title: "최고의 날", value: bestDayLabel)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(LiquidGlassStyle.titleText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlassCard(cornerRadius: 16)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiquidGlassSectionHeader(title: "일별 집중률", systemImage: "chart.xyaxis.line")

            Chart(dailyRatios, id: \.day) { item in
                AreaMark(
                    x: .value("요일", item.day),
                    y: .value("집중률", item.ratio)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [LiquidGlassStyle.aquaGlow.opacity(0.45), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("요일", item.day),
                    y: .value("집중률", item.ratio)
                )
                .foregroundStyle(LiquidGlassStyle.barChartFocusGradient)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(values: [0, 0.5, 1.0]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.15))
                    AxisValueLabel {
                        if let ratio = value.as(Double.self) {
                            Text("\(Int(ratio * 100))%")
                                .foregroundStyle(LiquidGlassStyle.secondaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                }
            }
            .frame(height: 200)
            .padding(12)
            .liquidGlassInsetPanel()
        }
        .padding(22)
        .liquidGlassCard()
    }

    private func goldenCard(_ insight: GoldenTimeInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LiquidGlassSectionHeader(title: "몰입 골든타임", systemImage: "sparkles")
            Text("\(insight.weekdayName) \(insight.bestHour)시 전후")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(LiquidGlassStyle.titleText)
                .liquidGlassReadableText()
            Text("이 시간대 집중 성공률이 \(Int(insight.successProbability * 100))%로 가장 높아요.")
                .font(.subheadline)
                .foregroundStyle(LiquidGlassStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .liquidGlassCard()
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LiquidGlassSectionHeader(title: "이번 주 회고", systemImage: "text.book.closed.fill")
            if journalEntries.isEmpty {
                Text("이번 주 작성한 회고가 없습니다.")
                    .font(.caption)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            } else {
                ForEach(journalEntries, id: \.0) { date, text in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shortJournalDate(date))
                            .font(.caption2)
                            .foregroundStyle(LiquidGlassStyle.tertiaryText)
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(LiquidGlassStyle.bodyText)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(22)
        .liquidGlassCard()
    }

    private func shortJournalDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d (E)"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }

    private func compute() {
        let engine = FocusStatisticsEngine(modelContext: modelContext)
        let summaries = engine.lastSevenDaysSummaries()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"

        var data: [(String, Double, TimeInterval)] = []
        for (offset, summary) in summaries.enumerated() {
            let dayDate = calendar.date(byAdding: .day, value: -(6 - offset), to: Date()) ?? Date()
            data.append((formatter.string(from: dayDate), summary.focusRatio, summary.focusSeconds))
        }
        dailyRatios = data.map { (day: $0.0, ratio: $0.1, focusSeconds: $0.2) }

        weekFocusSeconds = summaries.reduce(0) { $0 + $1.focusSeconds }
        let active = summaries.filter { $0.totalSeconds > 0 }
        averageRatio = active.isEmpty ? 0 : active.reduce(0) { $0 + $1.focusRatio } / Double(active.count)

        if let bestIndex = summaries.indices.max(by: { summaries[$0].focusSeconds < summaries[$1].focusSeconds }),
           summaries[bestIndex].focusSeconds > 0 {
            let dayDate = calendar.date(byAdding: .day, value: -(6 - bestIndex), to: Date()) ?? Date()
            bestDayLabel = formatter.string(from: dayDate) + "요일"
        }

        goldenInsight = GoldenTimeAnalyzer(modelContext: modelContext).analyze()
        weekComparison = engine.weekOverWeekComparison()
        journalEntries = JournalStore.entries(lastDays: 7)
    }
}

// MARK: - #1 Heatmap

struct FocusHeatmapCardView: View {
    let days: [FocusStatisticsEngine.HeatmapDay]
    var onOpenSheet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LiquidGlassSectionHeader(title: "집중 히트맵", systemImage: "calendar")
                Spacer()
                Button("전체 보기", action: onOpenSheet)
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
            }
            HeatmapGrid(days: Array(days.suffix(35)), columns: 7)
        }
        .padding(22)
        .liquidGlassCard()
    }
}

struct FocusHeatmapSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let days: [FocusStatisticsEngine.HeatmapDay]

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("집중 히트맵")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(LiquidGlassStyle.titleText)
                        Spacer()
                        Button("닫기") { dismiss() }.buttonStyle(LiquidGlassSecondaryButtonStyle())
                    }
                    HeatmapGrid(days: days, columns: 14)
                }
                .padding(28)
            }
        }
        .frame(minWidth: 560, minHeight: 480)
    }
}

private struct HeatmapGrid: View {
    let days: [FocusStatisticsEngine.HeatmapDay]
    let columns: Int

    private let levelColors: [Color] = [
        Color.white.opacity(0.08),
        LiquidGlassStyle.frost.opacity(0.35),
        LiquidGlassStyle.iceBlue.opacity(0.55),
        LiquidGlassStyle.aquaGlow.opacity(0.75),
        LiquidGlassStyle.mintGlow.opacity(0.95)
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(levelColors[day.level])
                    .frame(height: 14)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    .help(heatmapTooltip(day))
            }
        }
    }

    private func heatmapTooltip(_ day: FocusStatisticsEngine.HeatmapDay) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "ko_KR")
        return "\(f.string(from: day.date))\n집중 \(DurationFormat.hoursMinutes(day.focusSeconds)) · \(Int(day.focusRatio * 100))%"
    }
}

// MARK: - #2 Deep Work

struct DeepWorkCardView: View {
    let sessions: [FocusStatisticsEngine.DeepWorkSession]

    private var total: TimeInterval { sessions.reduce(0) { $0 + $1.duration } }
    private var longest: TimeInterval { sessions.map(\.duration).max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiquidGlassSectionHeader(title: "딥워크 세션", systemImage: "brain.head.profile")
            Text("오늘 \(sessions.count)회 · 최장 \(DurationFormat.hoursMinutes(longest)) · 총 \(DurationFormat.hoursMinutes(total))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.bodyText)
            if sessions.isEmpty {
                Text("25분 이상 끊김 없는 집중 블록이 없어요.")
                    .font(.caption)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            } else {
                ForEach(sessions.prefix(4)) { session in
                    HStack {
                        Text(timeRange(session))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(LiquidGlassStyle.secondaryText)
                        Spacer()
                        Text(DurationFormat.hoursMinutes(session.duration))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LiquidGlassStyle.iceBlue)
                    }
                }
            }
        }
        .padding(22)
        .liquidGlassCard()
    }

    private func timeRange(_ s: FocusStatisticsEngine.DeepWorkSession) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: s.start)) – \(f.string(from: s.end))"
    }
}

// MARK: - #3 Focus Depth

struct FocusDepthCardView: View {
    let metrics: FocusStatisticsEngine.FocusDepthMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiquidGlassSectionHeader(title: "집중 깊이", systemImage: "gauge.with.dots.needle.67percent")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(metrics.score)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                Text("/ 100")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            }
            Text("시간당 평균 \(String(format: "%.1f", metrics.switchesPerHour))회 앱 전환")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)
        }
        .padding(22)
        .liquidGlassCard()
    }
}

// MARK: - #4 Week Compare

struct WeekCompareCardView: View {
    let comparison: FocusStatisticsEngine.WeekComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiquidGlassSectionHeader(title: "이번 주 vs 지난 주", systemImage: "arrow.left.arrow.right")
            let delta = comparison.ratioDeltaPoints
            Text(String(format: "집중률 %+.0f%%p", delta))
                .font(.title3.weight(.bold))
                .foregroundStyle(delta >= 0 ? LiquidGlassStyle.mintGlow : LiquidGlassStyle.statusPaused)
            ForEach(comparison.categoryDeltas.prefix(4), id: \.0) { cat, change in
                HStack {
                    Text(cat.rawValue)
                        .font(.caption)
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                    Spacer()
                    Text("\(change >= 0 ? "▲" : "▼") \(DurationFormat.hoursMinutes(abs(change)))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LiquidGlassStyle.secondaryText)
                }
            }
        }
        .padding(22)
        .liquidGlassCard()
    }
}

// MARK: - #5 Hourly Curve

struct HourlyFocusCardView: View {
    let hourly: [FocusStatisticsEngine.HourlyFocus]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiquidGlassSectionHeader(title: "오늘 시간대별 집중", systemImage: "clock.fill")
            Chart(hourly) { item in
                AreaMark(x: .value("시", item.hour), y: .value("집중률", item.focusRatio))
                    .foregroundStyle(LinearGradient(colors: [LiquidGlassStyle.aquaGlow.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("시", item.hour), y: .value("집중률", item.focusRatio))
                    .foregroundStyle(LiquidGlassStyle.barChartFocusGradient)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .chartYScale(domain: 0...1)
            .chartXScale(domain: 0...23)
            .frame(height: 160)
            .padding(10)
            .liquidGlassInsetPanel()
        }
        .padding(22)
        .liquidGlassCard()
    }
}

// MARK: - #7 Projects

struct ProjectTrackingCardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var rangeDays = 7
    @State private var stats: [FocusStatisticsEngine.ProjectStat] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LiquidGlassSectionHeader(title: "프로젝트별 시간", systemImage: "folder.fill")
                Spacer()
                Picker("기간", selection: $rangeDays) {
                    Text("오늘").tag(1)
                    Text("7일").tag(7)
                    Text("30일").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            if stats.isEmpty {
                Text("세그먼트에 태그를 추가하면 프로젝트별로 모아요.")
                    .font(.caption)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            } else {
                ForEach(stats.prefix(6)) { stat in
                    HStack {
                        Text(stat.tag)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LiquidGlassStyle.bodyText)
                        Spacer()
                        Text("\(DurationFormat.hoursMinutes(stat.focusSeconds)) · \(Int(stat.focusRatio * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LiquidGlassStyle.secondaryText)
                    }
                }
            }
        }
        .padding(22)
        .liquidGlassCard()
        .onAppear(perform: reload)
        .onChange(of: rangeDays) { _, _ in reload() }
    }

    private func reload() {
        stats = FocusStatisticsEngine(modelContext: modelContext).projectStats(days: rangeDays)
    }
}

// MARK: - #11 Journal

struct JournalCardView: View {
    @State private var todayText = JournalStore.entry(for: Date())
    @State private var past = JournalStore.entries(lastDays: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiquidGlassSectionHeader(title: "오늘의 회고", systemImage: "text.book.closed.fill")
            TextField("한 줄 회고를 남겨보세요", text: $todayText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 10)
                .onChange(of: todayText) { _, v in
                    JournalStore.save(v, for: Date())
                    past = JournalStore.entries(lastDays: 7)
                }
            if !past.isEmpty {
                Divider().overlay(LiquidGlassStyle.divider)
                ForEach(past.prefix(3), id: \.0) { date, text in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shortDate(date)).font(.caption2).foregroundStyle(LiquidGlassStyle.tertiaryText)
                        Text(text).font(.caption).foregroundStyle(LiquidGlassStyle.secondaryText).lineLimit(2)
                    }
                }
            }
        }
        .padding(22)
        .liquidGlassCard()
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d (E)"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}

// MARK: - #14 Summary Card Export

struct TodaySummaryCardView: View {
    let focusRatio: Double
    let focusSeconds: TimeInterval
    let topApps: [AppUsage]
    let deepWorkCount: Int
    let depthScore: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("LifeLogger · 오늘 요약")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("\(Int(focusRatio * 100))% 집중")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(DurationFormat.hoursMinutes(focusSeconds) + " 집중 · 딥워크 \(deepWorkCount)회 · 깊이 \(depthScore)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            if let first = topApps.first {
                Text("Top · \(first.appName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.iceBlue)
            }
        }
        .padding(32)
        .frame(width: 420)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(GlassThemeStore.dashboardGradient)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(LiquidGlassStyle.borderGradient, lineWidth: 1.2))
        }
    }
}

enum SummaryCardExportService {
    @MainActor
    static func renderPNG(from view: some View, scale: CGFloat = 2) -> NSImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.nsImage
    }

    @MainActor
    static func saveOrCopy(view: some View, toClipboard: Bool) -> String? {
        guard let image = renderPNG(from: view) else { return "이미지 생성 실패" }
        if toClipboard {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
            return "클립보드에 복사했습니다."
        }
        let panel = NSSavePanel()
        panel.title = "요약 카드 저장"
        panel.nameFieldStringValue = "LifeLogger-summary.png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return "PNG 변환 실패" }
        do {
            try png.write(to: url)
            return "저장 완료: \(url.lastPathComponent)"
        } catch {
            return "저장 실패: \(error.localizedDescription)"
        }
    }
}

// MARK: - #16 Onboarding

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsGranted = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            VStack(spacing: 24) {
                Text("LifeLogger 시작하기")
                    .font(.title.weight(.bold))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                onboardingRow(
                    title: "손쉬운 사용",
                    detail: "창 제목 추적에 필요합니다.",
                    granted: WindowTitleExtractor.shared.isAccessibilityTrusted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                onboardingRow(
                    title: "알림",
                    detail: "뽀모도로·넛지·휴식 알림에 사용됩니다.",
                    granted: notificationsGranted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.notifications"
                )
                Button("시작하기") {
                    OnboardingStore.hasCompletedOnboarding = true
                    dismiss()
                }
                .buttonStyle(LiquidGlassPrimaryButtonStyle())
            }
            .padding(32)
            .frame(width: 440)
        }
        .onAppear {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let granted = settings.authorizationStatus == .authorized
                Task { @MainActor in notificationsGranted = granted }
            }
        }
    }

    private func onboardingRow(title: String, detail: String, granted: Bool, settingsURL: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? LiquidGlassStyle.mintGlow : LiquidGlassStyle.statusPaused)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline.weight(.semibold)).foregroundStyle(LiquidGlassStyle.titleText)
                Text(detail).font(.caption).foregroundStyle(LiquidGlassStyle.secondaryText)
                if !granted, let url = URL(string: settingsURL) {
                    Button("시스템 설정 열기") { NSWorkspace.shared.open(url) }
                        .buttonStyle(LiquidGlassSecondaryButtonStyle())
                }
            }
            Spacer()
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 14)
    }
}

// MARK: - #15 Menu Bar Popover

struct MenuBarPopoverView: View {
    @ObservedObject var tracker: ActivityTracker
    let topApps: [AppUsage]
    let focusRatio: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(Int(focusRatio * 100))%")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                Text("오늘 집중")
                    .font(.caption)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                Spacer()
            }
            ForEach(topApps.prefix(3)) { app in
                HStack {
                    Text(app.appName).font(.caption).lineLimit(1)
                    Spacer()
                    Text(DurationFormat.hoursMinutes(app.seconds)).font(.caption2.monospacedDigit())
                }
                .foregroundStyle(LiquidGlassStyle.bodyText)
            }
            Button(tracker.isTracking ? "일시정지" : "시작") {
                tracker.toggleTracking()
            }
            .buttonStyle(LiquidGlassPrimaryButtonStyle())
        }
        .padding(16)
        .frame(width: 240)
        .background(LiquidGlassBackground())
    }
}
