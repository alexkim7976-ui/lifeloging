import SwiftUI
import AppKit

struct FeatureRoadmapView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var runtime = MacFeatureRuntime.shared

    @State private var features: [MacFeature] = MacFeatureCatalog.loadFeatures()
    @State private var searchText = ""
    @State private var selectedCategory = "all"
    @State private var selectedStatus: MacFeatureStatus?
    @State private var bookmarksOnly = false
    @State private var bookmarkRevision = 0
    @State private var actionMessage: String?
    @State private var showActionAlert = false

    private var filtered: [MacFeature] {
        let bookmarked = MacFeatureBookmarks.bookmarkedIDs()
        return features.filter { feature in
            if bookmarksOnly, !bookmarked.contains(feature.id) { return false }
            if selectedCategory != "all", feature.categoryId != selectedCategory { return false }
            if let selectedStatus, feature.status != selectedStatus { return false }
            if searchText.isEmpty { return true }
            return feature.title.localizedCaseInsensitiveContains(searchText)
                || feature.categoryName.localizedCaseInsensitiveContains(searchText)
                || feature.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var summary: (implemented: Int, partial: Int, planned: Int) {
        MacFeatureCatalog.summary(from: features)
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 16) {
                header
                summaryRow
                filters
                featureList
            }
            .padding(24)
        }
        .frame(minWidth: 720, minHeight: 640)
        .id(languageStore.language.rawValue)
        .onAppear {
            features = MacFeatureCatalog.loadFeatures()
            runtime.refreshAllStates()
        }
        .alert(L10n.tr("features.action.title"), isPresented: $showActionAlert) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(actionMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            LiquidGlassSectionHeader(
                title: L10n.tr("features.title"),
                systemImage: "square.grid.3x3.fill"
            )
            Spacer()
            Text(L10n.tr("features.count", MacFeatureCatalog.totalCount))
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)
            Button(L10n.tr("features.export")) { exportCSV() }
                .buttonStyle(LiquidGlassSecondaryButtonStyle())
            Button(L10n.tr("common.close")) { dismiss() }
                .buttonStyle(LiquidGlassSecondaryButtonStyle())
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryChip(
                label: MacFeatureStatus.implemented.label,
                count: summary.implemented,
                tint: LiquidGlassStyle.mintGlow
            )
            summaryChip(
                label: MacFeatureStatus.partial.label,
                count: summary.partial,
                tint: LiquidGlassStyle.iceBlue
            )
            summaryChip(
                label: MacFeatureStatus.planned.label,
                count: summary.planned,
                tint: LiquidGlassStyle.secondaryText
            )
            Spacer()
        }
    }

    private func summaryChip(label: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
            Text("\(count)")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .liquidGlassInsetPanel(cornerRadius: 8)
    }

    private var filters: some View {
        VStack(spacing: 10) {
            TextField(L10n.tr("features.search"), text: $searchText)
                .textFieldStyle(.plain)
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: L10n.tr("features.allCategories"), active: selectedCategory == "all") {
                        selectedCategory = "all"
                    }
                    ForEach(MacFeatureCatalog.categories(from: features), id: \.id) { category in
                        filterChip(title: category.name, active: selectedCategory == category.id) {
                            selectedCategory = category.id
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                filterChip(title: L10n.tr("features.allStatuses"), active: selectedStatus == nil) {
                    selectedStatus = nil
                }
                ForEach(MacFeatureStatus.allCases, id: \.self) { status in
                    filterChip(title: status.label, active: selectedStatus == status) {
                        selectedStatus = status
                    }
                }
                Toggle(isOn: $bookmarksOnly) {
                    Text(L10n.tr("features.bookmarksOnly"))
                        .font(.caption)
                }
                .toggleStyle(.switch)
            }
        }
    }

    private func filterChip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(active ? LiquidGlassStyle.titleText : LiquidGlassStyle.secondaryText)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(active ? LiquidGlassStyle.aquaGlow.opacity(0.35) : Color.white.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
    }

    private var featureList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filtered) { feature in
                    featureRow(feature)
                }
            }
        }
    }

    private func featureRow(_ feature: MacFeature) -> some View {
        let bookmarked = MacFeatureBookmarks.isBookmarked(feature.id)
        _ = bookmarkRevision

        return HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%03d", feature.index))
                .font(.caption.monospacedDigit())
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
                .frame(width: 36, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.bodyText)
                Text(feature.categoryName)
                    .font(.caption2)
                    .foregroundStyle(LiquidGlassStyle.tertiaryText)
                if let live = runtime.liveState(for: feature.id) {
                    Text(live.value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LiquidGlassStyle.iceBlue)
                }
            }

            Spacer()

            Button(L10n.tr("features.use")) {
                let result = runtime.perform(featureId: feature.id)
                actionMessage = result.message
                showActionAlert = true
            }
            .buttonStyle(LiquidGlassSecondaryButtonStyle())

            statusBadge(feature.status)

            Button {
                MacFeatureBookmarks.toggle(feature.id)
                bookmarkRevision += 1
            } label: {
                Image(systemName: bookmarked ? "star.fill" : "star")
                    .foregroundStyle(bookmarked ? LiquidGlassStyle.statusPaused : LiquidGlassStyle.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .liquidGlassInsetPanel(cornerRadius: 12)
    }

    private func statusBadge(_ status: MacFeatureStatus) -> some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(statusColor(status))
            .background {
                Capsule().fill(statusColor(status).opacity(0.18))
            }
    }

    private func statusColor(_ status: MacFeatureStatus) -> Color {
        switch status {
        case .implemented: return LiquidGlassStyle.mintGlow
        case .partial: return LiquidGlassStyle.iceBlue
        case .planned: return LiquidGlassStyle.secondaryText
        }
    }

    private func exportCSV() {
        let csv = MacFeatureCatalog.exportCSV(features: features)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "lifelogger-mac-features.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
