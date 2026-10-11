import SwiftUI

struct FocusRingView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let screenOnSeconds: TimeInterval
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        min(1, max(0, screenOnSeconds / (24 * 3600)))
    }

    private var durationFontSize: CGFloat {
        screenOnSeconds >= 3600 ? 28 : 36
    }

    var body: some View {
        ZStack {
            LiquidGlassSurface(cornerRadius: 999, strong: true)
                .frame(width: 196, height: 196)

            Circle()
                .stroke(LiquidGlassStyle.glassBorderSoft, lineWidth: 14)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LiquidGlassStyle.focusRingGradient,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: LiquidGlassStyle.aquaGlow.opacity(0.50), radius: 12)
                .shadow(color: LiquidGlassStyle.glassShadowSoft, radius: 4, y: 2)

            VStack(spacing: 6) {
                Text(DurationFormat.ringDuration(screenOnSeconds))
                    .font(.system(size: durationFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                    .liquidGlassReadableText()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Text(L10n.tr("focus.ring.label"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 196, height: 196)
        .id(languageStore.language.rawValue)
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.75)) {
                animatedProgress = progress
            }
        }
        .onChange(of: screenOnSeconds) { _, _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Feature: 하루 집중 목표 + 연속 달성(Streak)

struct DailyGoalCardView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let focusSeconds: TimeInterval
    let streak: Int
    @Binding var goalMinutes: Int

    @State private var showGoalEditor = false
    @State private var draftMinutes: Double = 120
    @State private var animatedProgress: Double = 0

    private var goalSeconds: TimeInterval { TimeInterval(goalMinutes * 60) }
    private var progress: Double { min(max(goalSeconds > 0 ? focusSeconds / goalSeconds : 0, 0), 1) }
    private var remaining: TimeInterval { max(0, goalSeconds - focusSeconds) }
    private var achieved: Bool { focusSeconds >= goalSeconds && goalSeconds > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LiquidGlassSectionHeader(title: L10n.tr("focus.goal.title"), systemImage: "target")
                Spacer()
                goalPickerButton
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("focus.goal.today"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LiquidGlassStyle.tertiaryText)
                    Text(DurationFormat.hoursMinutes(focusSeconds))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(LiquidGlassStyle.titleText)
                        .liquidGlassReadableText()
                }
                Button {
                    draftMinutes = Double(goalMinutes)
                    showGoalEditor = true
                } label: {
                    Text("/ \(DailyFocusGoalStore.label(forMinutes: goalMinutes))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LiquidGlassStyle.iceBlue)
                        .underline(pattern: .dot, color: LiquidGlassStyle.iceBlue.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("focus.goal.edit"))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LiquidGlassStyle.barChartFocusGradient)
                        .frame(width: max(8, geo.size.width * animatedProgress))
                        .shadow(color: LiquidGlassStyle.aquaGlow.opacity(0.45), radius: 6)
                }
            }
            .frame(height: 12)

            HStack(spacing: 8) {
                if achieved {
                    Label(L10n.tr("focus.goal.achieved"), systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LiquidGlassStyle.mintGlow)
                } else {
                    Text(L10n.tr("focus.goal.remaining", DurationFormat.hoursMinutes(remaining)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LiquidGlassStyle.secondaryText)
                }
                Spacer()
                if streak > 0 {
                    Label(L10n.tr("focus.goal.streak", streak), systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LiquidGlassStyle.statusPaused)
                }
            }
        }
        .padding(22)
        .liquidGlassCard()
        .onAppear {
            draftMinutes = Double(goalMinutes)
            animate()
        }
        .onChange(of: focusSeconds) { _, _ in animate() }
        .onChange(of: goalMinutes) { _, _ in animate() }
        .popover(isPresented: $showGoalEditor, arrowEdge: .top) {
            goalEditorPopover
        }
        .id(languageStore.language.rawValue)
    }

    private var goalPickerButton: some View {
        Button {
            draftMinutes = Double(goalMinutes)
            showGoalEditor = true
        } label: {
            HStack(spacing: 4) {
                Text("목표 \(DailyFocusGoalStore.label(forMinutes: goalMinutes))")
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(LiquidGlassStyle.iceBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .liquidGlassInsetPanel(cornerRadius: 8)
        }
        .buttonStyle(.plain)
        .help(L10n.tr("focus.goal.edit"))
    }

    private var goalEditorPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("focus.goal.set"))
                .font(.headline.weight(.bold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Text(DailyFocusGoalStore.label(forMinutes: Int(draftMinutes)))
                .font(.title3.weight(.bold))
                .foregroundStyle(LiquidGlassStyle.iceBlue)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(DailyFocusGoalStore.options, id: \.self) { minutes in
                    Button {
                        draftMinutes = Double(minutes)
                    } label: {
                        Text(DailyFocusGoalStore.shortLabel(forMinutes: minutes))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(
                                Int(draftMinutes) == minutes
                                    ? LiquidGlassStyle.titleText
                                    : LiquidGlassStyle.secondaryText
                            )
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        Int(draftMinutes) == minutes
                                            ? LiquidGlassStyle.aquaGlow.opacity(0.35)
                                            : Color.white.opacity(0.08)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("직접 조절 · \(Int(draftMinutes))분")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                Slider(value: $draftMinutes, in: 15...480, step: 15)
            }

            HStack {
                Button(L10n.tr("common.cancel")) { showGoalEditor = false }
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
                Button(L10n.tr("common.apply")) { applyGoal() }
                    .buttonStyle(LiquidGlassPrimaryButtonStyle())
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(LiquidGlassBackground())
    }

    private func applyGoal() {
        let minutes = Int(draftMinutes)
        goalMinutes = minutes
        DailyFocusGoalStore.goalMinutes = minutes
        showGoalEditor = false
        animate()
    }

    private func animate() {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) {
            animatedProgress = progress
        }
    }
}
