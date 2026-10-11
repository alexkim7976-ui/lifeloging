import SwiftUI

struct CurrentActivityCardView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @EnvironmentObject private var tracker: ActivityTracker
    @EnvironmentObject private var friendShare: FriendShareCoordinator

    let focusRatioToday: Double

    @State private var tick = Date()

    private var snapshot: CurrentActivitySnapshot {
        CurrentActivityShareService.snapshot(from: tracker, focusRatioToday: focusRatioToday)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            activityBody
            shareActions
        }
        .padding(22)
        .liquidGlassCard(strong: true)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            tick = date
        }
        .id(languageStore.language.rawValue)
    }

    private var headerRow: some View {
        HStack {
            LiquidGlassSectionHeader(title: L10n.tr("activity.title"), systemImage: "location.fill")
            Spacer()
            LiquidGlassBadge(
                text: snapshot.statusLabel,
                tint: statusTint
            )
        }
    }

    private var activityBody: some View {
        HStack(alignment: .top, spacing: 16) {
            AppIconView(
                appName: snapshot.appName,
                bundleIdentifier: snapshot.bundleIdentifier
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                    .lineLimit(1)
                    .liquidGlassReadableText()

                Text(snapshot.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    metaChip(icon: "clock", text: snapshot.elapsedLabel)
                    metaChip(icon: "target", text: "오늘 \(snapshot.focusPercentLabel)")
                    metaChip(icon: snapshot.category.systemImage, text: snapshot.category.localizedName)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
    }

    private var shareActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                friendShare.presentShareSheet(snapshot: snapshot)
            } label: {
                Label(L10n.tr("activity.share"), systemImage: "paperplane.fill")
            }
            .buttonStyle(LiquidGlassPrimaryButtonStyle())

            if !snapshot.canShare {
                Text(trackingHint)
                    .font(.footnote)
                    .foregroundStyle(LiquidGlassStyle.tertiaryText)
            }
        }
    }

    private var trackingHint: String {
        if !tracker.isTracking {
            return L10n.tr("activity.trackingHint.notTracking")
        }
        if tracker.isAFK {
            return L10n.tr("activity.trackingHint.afk")
        }
        return L10n.tr("activity.trackingHint.detecting")
    }

    private var statusTint: Color {
        if !tracker.isTracking { return LiquidGlassStyle.statusPaused }
        if tracker.isAFK { return LiquidGlassStyle.statusAfk }
        if tracker.currentAppName.isEmpty { return LiquidGlassStyle.lavenderMist }
        return LiquidGlassStyle.statusActive
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(LiquidGlassStyle.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.12))
        }
    }
}
