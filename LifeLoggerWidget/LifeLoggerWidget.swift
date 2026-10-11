import WidgetKit
import SwiftUI
import Charts

struct LifeLoggerEntry: TimelineEntry {
    let date: Date
    let stats: SharedStatistics
}

struct LifeLoggerProvider: TimelineProvider {
    func placeholder(in context: Context) -> LifeLoggerEntry {
        LifeLoggerEntry(date: Date(), stats: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (LifeLoggerEntry) -> Void) {
        completion(LifeLoggerEntry(date: Date(), stats: SharedStatistics.readFromAppGroup()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LifeLoggerEntry>) -> Void) {
        let entry = LifeLoggerEntry(date: Date(), stats: SharedStatistics.readFromAppGroup())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct LifeLoggerWidget: Widget {
    let kind = "LifeLoggerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LifeLoggerProvider()) { entry in
            LifeLoggerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LifeLogger")
        .description("바탕화면에서 집중 비율을 확인하고 트래킹을 제어하세요.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(macOS 15.0, *) {
            families.append(.systemExtraLarge)
        }
        return families
    }
}

/// 바탕화면 전용 컴팩트 위젯 (위젯 갤러리에서 별도 선택 가능)
struct LifeLoggerDesktopWidget: Widget {
    let kind = "LifeLoggerDesktopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LifeLoggerProvider()) { entry in
            LifeLoggerSmallWidgetView(entry: entry)
        }
        .configurationDisplayName("LifeLogger · 바탕화면")
        .description("작은 크기로 바탕화면에 고정하기 좋은 집중 위젯입니다.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct LifeLoggerWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeLoggerWidget()
        LifeLoggerDesktopWidget()
    }
}
