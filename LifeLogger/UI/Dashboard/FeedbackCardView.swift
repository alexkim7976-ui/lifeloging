import SwiftUI

struct FeedbackCardView: View {
    @ObservedObject var localContext: LocalContextService
    @ObservedObject private var languageStore = AppLanguageStore.shared

    let focusRatio: Double
    let totalHours: Double
    let focusHours: Double

    private var focusInsight: String? {
        switch focusRatio {
        case 0.75...: return L10n.tr("feedback.insight.excellent")
        case 0.55..<0.75: return L10n.tr("feedback.insight.good")
        case 0.35..<0.55: return L10n.tr("feedback.insight.ok")
        case 0.15..<0.35: return L10n.tr("feedback.insight.start")
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(localContext.timeOfDayEmoji)
                    .font(.system(size: 34))
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(localContext.timeTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(LiquidGlassStyle.titleText)
                        .monospacedDigit()
                        .liquidGlassReadableText()

                    Text(localContext.locationAndDateSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let focusInsight {
                        Text(focusInsight)
                            .font(.caption)
                            .foregroundStyle(LiquidGlassStyle.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(LiquidGlassStyle.divider)
                .frame(height: 1)

            HStack(spacing: 28) {
                statItem(label: L10n.tr("feedback.stat.focus"), value: DurationFormat.hoursMinutes(focusHours))
                statItem(label: L10n.tr("feedback.stat.total"), value: DurationFormat.hoursMinutes(totalHours))
            }
        }
        .padding(22)
        .liquidGlassCard(strong: true)
        .id(languageStore.language.rawValue)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(LiquidGlassStyle.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(LiquidGlassStyle.titleText)
                .liquidGlassReadableText()
        }
    }
}
