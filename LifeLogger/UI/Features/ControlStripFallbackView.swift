import SwiftUI

struct ControlStripFallbackView: View {
    @ObservedObject var tracker: ActivityTracker
    let focusRatio: Double
    let onCommandPalette: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            stripButton(
                title: tracker.isTracking ? L10n.tr("dashboard.pomodoro.pause") : L10n.tr("dashboard.pomodoro.start"),
                systemImage: tracker.isTracking ? "pause.fill" : "play.fill",
                tint: LiquidGlassStyle.mintGlow
            ) {
                tracker.toggleTracking()
            }

            stripButton(
                title: L10n.tr("controlStrip.focusSession"),
                systemImage: FocusSessionStore.isActive ? "bolt.fill" : "bolt",
                tint: LiquidGlassStyle.iceBlue
            ) {
                _ = FocusSessionStore.toggle()
            }

            VStack(spacing: 2) {
                Text("\(Int(focusRatio * 100))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                Text(L10n.tr("controlStrip.focusToday"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            }
            .frame(minWidth: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.currentAppName.isEmpty ? "—" : tracker.currentAppName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(FeatureMetricsStore.string("context.currentTag", default: tracker.currentCategory.rawValue))
                    .font(.system(size: 9))
                    .foregroundStyle(LiquidGlassStyle.tertiaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: 140, alignment: .leading)

            Spacer(minLength: 8)

            stripButton(
                title: "⌘K",
                systemImage: "command",
                tint: LiquidGlassStyle.secondaryText
            ) {
                onCommandPalette()
            }

            closeButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(LiquidGlassStyle.borderGradient, lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.25), radius: 16, y: 4)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)
                .frame(width: 26, height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
        .help(L10n.tr("controlStrip.close"))
    }

    private func stripButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .frame(width: 56, height: 44)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
    }
}
