import SwiftUI
import AppKit

struct NotchHUDView: View {
    @EnvironmentObject private var tracker: ActivityTracker
    @EnvironmentObject private var friendShare: FriendShareCoordinator
    @State private var isExpanded = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var tick = Date()

    private var shareSnapshot: CurrentActivitySnapshot {
        CurrentActivityShareService.snapshot(
            from: tracker,
            focusRatioToday: tracker.todayFocusRatio
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            notchBox
                .frame(width: isExpanded ? 360 : 210, height: isExpanded ? 88 : 44)
                .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isExpanded)
                .onHover { hovering in
                    hoverTask?.cancel()
                    if hovering {
                        isExpanded = true
                    } else {
                        hoverTask = Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            guard !Task.isCancelled else { return }
                            await MainActor.run { isExpanded = false }
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            tick = date
        }
    }

    private var notchBox: some View {
        HStack(spacing: isExpanded ? 14 : 8) {
            statusIndicator

            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .padding(.horizontal, isExpanded ? 18 : 14)
        .padding(.vertical, isExpanded ? 15 : 10)
        .background {
            RoundedRectangle(cornerRadius: isExpanded ? 20 : 19, style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    RoundedRectangle(cornerRadius: isExpanded ? 20 : 19, style: .continuous)
                        .fill(LiquidGlassStyle.panelGradient)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: isExpanded ? 20 : 19, style: .continuous)
                        .strokeBorder(LiquidGlassStyle.borderGradient, lineWidth: 1.1)
                }
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: isExpanded ? 20 : 19, style: .continuous)
                        .fill(LiquidGlassStyle.specularHighlight)
                        .blendMode(.overlay)
                }
                .shadow(color: LiquidGlassStyle.glassShadowSoft, radius: 18, y: 8)
                .shadow(color: LiquidGlassStyle.glassShadow, radius: 6, y: 3)
        }
        .foregroundStyle(.white)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 9, height: 9)
            .shadow(color: statusColor.opacity(0.75), radius: 5)
            .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 0.5))
    }

    private var collapsedContent: some View {
        HStack(spacing: 10) {
            Text(shareSnapshot.elapsedHumanLabel)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .liquidGlassReadableText()
            Text("·")
                .foregroundStyle(.white.opacity(0.45))
            Text(shareSnapshot.focusMoodLabel)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(LiquidGlassStyle.iceBlue)
                .lineLimit(1)
        }
        .id(tick)
    }

    private var expandedContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(displayAppName)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .liquidGlassReadableText()
                if !displayWindowTitle.isEmpty {
                    Text(displayWindowTitle)
                        .font(.caption2)
                        .foregroundStyle(LiquidGlassStyle.secondaryText)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(tracker.currentCategory.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(LiquidGlassStyle.secondaryText)
                    if tracker.isAFK {
                        Text("AFK")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(shareSnapshot.elapsedHumanLabel)
                    .font(.caption.weight(.bold))
                    .multilineTextAlignment(.trailing)
                Text(shareSnapshot.focusMoodLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.iceBlue)
                    .multilineTextAlignment(.trailing)
            }
            .id(tick)

            if canShareCurrentActivity {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    friendShare.presentShareSheet(snapshot: shareSnapshot)
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .help("친구에게 공유")
            }
        }
    }

    private var statusColor: Color {
        if tracker.isAFK { return LiquidGlassStyle.statusAfk }
        if tracker.isTracking { return LiquidGlassStyle.statusActive }
        return LiquidGlassStyle.lavenderMist.opacity(0.85)
    }

    private var displayAppName: String {
        if tracker.isAFK { return "자리 비움" }
        if tracker.currentAppName.isEmpty { return "분석 중…" }
        return tracker.currentAppName
    }

    private var displayWindowTitle: String {
        if tracker.isAFK || tracker.currentWindowTitle.isEmpty { return "" }
        return tracker.currentWindowTitle
    }

    private var canShareCurrentActivity: Bool {
        shareSnapshot.canShare
    }
}
