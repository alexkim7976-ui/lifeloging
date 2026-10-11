import SwiftUI
import WidgetKit
import Charts

struct LifeLoggerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LifeLoggerEntry

    var body: some View {
        switch family {
        case .systemSmall:
            LifeLoggerSmallWidgetView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            LifeLoggerLargeWidgetView(entry: entry)
        default:
            LifeLoggerMediumWidgetView(entry: entry)
        }
    }
}

struct LifeLoggerSmallWidgetView: View {
    let entry: LifeLoggerEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(entry.stats.isTrackingEnabled ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text("LifeLogger")
                    .font(.caption2.weight(.semibold))
                Spacer()
            }

            Text("\(Int(entry.stats.todayFocusRatio * 100))%")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)

            Text("오늘 집중")
                .font(.caption2)
                .foregroundStyle(.secondary)

            WidgetTrackingButton(isTracking: entry.stats.isTrackingEnabled, compact: true)
        }
        .padding(12)
        .widgetGlassBackground()
    }
}

struct LifeLoggerMediumWidgetView: View {
    let entry: LifeLoggerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetStatusHeader(isTracking: entry.stats.isTrackingEnabled)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(entry.stats.todayFocusRatio * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("오늘 집중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SevenDayFocusChart(ratios: entry.stats.lastSevenDayFocusRatios, height: 44)

            WidgetTrackingFooter(
                isTracking: entry.stats.isTrackingEnabled,
                currentAppName: entry.stats.currentAppName,
                detailed: false
            )
        }
        .padding()
        .widgetGlassBackground()
    }
}

struct LifeLoggerLargeWidgetView: View {
    let entry: LifeLoggerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LifeLogger")
                        .font(.title3.weight(.bold))
                    Text(entry.stats.isTrackingEnabled ? "추적 중" : "일시정지")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(entry.stats.todayFocusRatio * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("오늘 집중")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                WidgetStatBlock(title: "집중", value: formatDuration(entry.stats.todayFocusSeconds))
                WidgetStatBlock(title: "전체", value: formatDuration(entry.stats.todayTotalSeconds))
            }

            SevenDayFocusChart(ratios: entry.stats.lastSevenDayFocusRatios, height: 88)

            WidgetTrackingFooter(
                isTracking: entry.stats.isTrackingEnabled,
                currentAppName: entry.stats.currentAppName,
                detailed: true
            )
        }
        .padding()
        .widgetGlassBackground()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

private struct WidgetStatusHeader: View {
    let isTracking: Bool

    var body: some View {
        HStack {
            Text("LifeLogger")
                .font(.headline)
            Spacer()
            Image(systemName: isTracking ? "record.circle.fill" : "pause.circle")
                .foregroundStyle(isTracking ? .green : .orange)
        }
    }
}

private struct WidgetStatBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetTrackingButton: View {
    let isTracking: Bool
    var compact: Bool = false

    var body: some View {
        Button(intent: ToggleTrackingIntent()) {
            if compact {
                Image(systemName: isTracking ? "pause.fill" : "play.fill")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            } else {
                Label(
                    isTracking ? "일시정지" : "시작",
                    systemImage: isTracking ? "pause.fill" : "play.fill"
                )
                .font(.caption.weight(.semibold))
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(compact ? .small : .regular)
    }
}

private struct WidgetTrackingFooter: View {
    let isTracking: Bool
    let currentAppName: String?
    let detailed: Bool

    var body: some View {
        HStack {
            WidgetTrackingButton(isTracking: isTracking)
            Spacer()
            if detailed, let app = currentAppName {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("현재 앱")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(app)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }
            } else if let app = currentAppName {
                Text(app)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SevenDayFocusChart: View {
    let ratios: [Double]
    let height: CGFloat

    var body: some View {
        if ratios.contains(where: { $0 > 0 }) {
            Chart(Array(ratios.enumerated()), id: \.offset) { index, ratio in
                LineMark(
                    x: .value("Day", index),
                    y: .value("Focus", ratio * 100)
                )
                .foregroundStyle(Color.cyan.gradient)
                AreaMark(
                    x: .value("Day", index),
                    y: .value("Focus", ratio * 100)
                )
                .foregroundStyle(Color.cyan.opacity(0.2).gradient)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: height)
        }
    }
}

private extension View {
    func widgetGlassBackground() -> some View {
        containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.52, blue: 0.88),
                    Color(red: 0.10, green: 0.32, blue: 0.66),
                    Color(red: 0.06, green: 0.18, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
