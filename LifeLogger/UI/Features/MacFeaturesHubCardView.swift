import SwiftUI

struct MacFeaturesHubCardView: View {
    @ObservedObject private var runtime = MacFeatureRuntime.shared
    @State private var showRoadmap = false

    private var activeCount: Int {
        runtime.liveStates.values.filter(\.isActive).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LiquidGlassSectionHeader(
                    title: L10n.tr("features.title"),
                    systemImage: "square.grid.3x3.fill"
                )
                Spacer()
                Text(L10n.tr("features.count", MacFeatureCatalog.totalCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.iceBlue)
            }

            Text(L10n.tr("features.hub.subtitle"))
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            HStack(spacing: 10) {
                Label("\(activeCount)", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LiquidGlassStyle.mintGlow)
                Text(L10n.tr("features.hub.active"))
                    .font(.caption)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                Spacer()
                Button(L10n.tr("features.settings.open")) { showRoadmap = true }
                    .buttonStyle(LiquidGlassPrimaryButtonStyle())
            }
        }
        .padding(22)
        .liquidGlassCard()
        .sheet(isPresented: $showRoadmap) {
            FeatureRoadmapView()
        }
    }
}
