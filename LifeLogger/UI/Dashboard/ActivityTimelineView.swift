import SwiftUI
import SwiftData
import EventKit

struct ActivityTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let segments: [ActivitySegment]
    var referenceNow: Date = Date()

    @State private var calendarEvents: [EKEvent] = []
    @State private var showCalendar = false
    @State private var editingSegment: ActivitySegment?
    @State private var editCategory: ActivityCategory = .coding
    @State private var editTag = ""
    @State private var editNote = ""
    @State private var tagSuggestions: [String] = []

    private var timelineSegments: [ActivitySegment] {
        Array(segments.suffix(60))
    }

    private var resolvedEnds: [UUID: Date] {
        SegmentDurationCalculator.resolvedEnds(for: timelineSegments, now: referenceNow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LiquidGlassSectionHeader(title: L10n.tr("timeline.title"), systemImage: "timeline.selection")
                Spacer()
                Toggle(L10n.tr("timeline.calendar"), isOn: $showCalendar)
                    .toggleStyle(.switch)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                    .onChange(of: showCalendar) { _, on in
                        if on { Task { await loadCalendar() } }
                    }
            }

            if showCalendar, !calendarEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(calendarEvents.prefix(4), id: \.eventIdentifier) { event in
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundStyle(LiquidGlassStyle.statusPaused)
                            Text(event.title ?? L10n.tr("timeline.eventFallback"))
                                .font(.caption)
                                .foregroundStyle(LiquidGlassStyle.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 10)
            }

            if segments.isEmpty {
                Text(L10n.tr("timeline.empty"))
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(timelineSegments, id: \.id) { segment in
                                let displayDuration = segmentDisplayDuration(segment)
                                TimelineBlock(
                                    segment: segment,
                                    displayDuration: displayDuration
                                )
                                .id(segment.id)
                                .onTapGesture { openEditor(for: segment) }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: timelineSegments.count) { _, _ in
                        if let last = timelineSegments.last?.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last, anchor: .trailing)
                            }
                        }
                    }
                    .onChange(of: referenceNow) { _, _ in
                        if let last = timelineSegments.last?.id {
                            proxy.scrollTo(last, anchor: .trailing)
                        }
                    }
                }
                .liquidGlassInsetPanel()
            }
        }
        .padding(22)
        .liquidGlassCard()
        .id(languageStore.language.rawValue)
        .sheet(item: $editingSegment) { segment in
            segmentEditSheet(segment)
        }
    }

    private func segmentDisplayDuration(_ segment: ActivitySegment) -> TimeInterval {
        SegmentDurationCalculator.durationOnDay(
            segment: segment,
            date: referenceNow,
            now: referenceNow,
            resolvedEnd: resolvedEnds[segment.id]
        )
    }

    private func openEditor(for segment: ActivitySegment) {
        editingSegment = segment
        editCategory = segment.effectiveCategory
        editTag = segment.tag ?? ""
        editNote = segment.note ?? ""
        tagSuggestions = FocusStatisticsEngine(modelContext: modelContext).allTags()
    }

    @ViewBuilder
    private func segmentEditSheet(_ segment: ActivitySegment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("timeline.editTitle"))
                .font(.headline.weight(.bold))
                .foregroundStyle(LiquidGlassStyle.titleText)
            Text("\(segment.appName) · \(DurationFormat.hoursMinutes(segmentDisplayDuration(segment)))")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)
            Picker(L10n.tr("timeline.category"), selection: $editCategory) {
                ForEach(ActivityCategory.allCases, id: \.self) { cat in
                    Text(cat.localizedName).tag(cat)
                }
            }
            TextField(L10n.tr("timeline.projectTag"), text: $editTag)
                .textFieldStyle(.plain)
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 10)
            if !tagSuggestions.isEmpty {
                Text(L10n.tr("timeline.existingTags", tagSuggestions.prefix(5).joined(separator: ", ")))
                    .font(.caption2)
                    .foregroundStyle(LiquidGlassStyle.tertiaryText)
            }
            TextField(L10n.tr("timeline.note"), text: $editNote, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 10)
            HStack {
                Button(L10n.tr("common.cancel")) { editingSegment = nil }
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
                Button(L10n.tr("timeline.mergeNext")) {
                    _ = SegmentEditService.mergeWithNext(segment, modelContext: modelContext)
                    editingSegment = nil
                }
                .buttonStyle(LiquidGlassSecondaryButtonStyle())
                Button(L10n.tr("timeline.save")) {
                    segment.userCategoryRaw = editCategory.rawValue
                    segment.tag = editTag.isEmpty ? nil : SecureInputValidator.sanitizeText(editTag, maxLength: 40)
                    segment.note = editNote.isEmpty ? nil : SecureInputValidator.sanitizeText(editNote, maxLength: 200)
                    try? modelContext.save()
                    editingSegment = nil
                }
                .buttonStyle(LiquidGlassPrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(LiquidGlassBackground())
    }

    private func loadCalendar() async {
        _ = await CalendarOverlayService.requestAccess()
        calendarEvents = CalendarOverlayService.events(for: Date())
    }
}

extension ActivitySegment: Identifiable {}

private struct TimelineBlock: View {
    let segment: ActivitySegment
    let displayDuration: TimeInterval

    private var blockColor: Color {
        Color(hex: segment.effectiveCategory.accentHex) ?? LiquidGlassStyle.skyBlue
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(blockColor.opacity(segment.effectiveCategory.isFocusCategory ? 0.95 : 0.60))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            }
            .frame(width: max(8, displayDuration / 28), height: 40)
            .shadow(color: blockColor.opacity(0.35), radius: 3, y: 1)
            .help(tooltip)
    }

    private var tooltip: String {
        var t = "\(segment.appName) · \(segment.effectiveCategory.localizedName)"
        if let tag = segment.effectiveTag { t += " · #\(tag)" }
        return t
    }
}
