import SwiftUI

struct DesktopWidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("바탕화면 위젯 추가")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(LiquidGlassStyle.titleText)
                        Text("LifeLogger 위젯을 Mac 바탕화면에 고정하세요.")
                            .font(.subheadline)
                            .foregroundStyle(LiquidGlassStyle.secondaryText)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 14) {
                    guideStep(number: 1, text: "바탕화면 빈 곳에서 Control + 클릭 (또는 우클릭)")
                    guideStep(number: 2, text: "「위젯 편집…」 선택")
                    guideStep(number: 3, text: "검색창에 「LifeLogger」 입력")
                    guideStep(number: 4, text: "원하는 크기(작음/중간/큼)를 바탕화면으로 드래그")
                }
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(title: "추천 위젯", systemImage: "sparkles")
                    Label("LifeLogger · 바탕화면 — 작은 크기, ▶️/⏸️ 버튼 포함", systemImage: "square.grid.2x2")
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                    Label("LifeLogger — 중/대형, 7일 추세 차트 포함", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                }
                .padding(18)
                .liquidGlassCard(cornerRadius: 16)

                Text("앱이 실행 중일 때 데이터가 자동으로 갱신됩니다.")
                    .font(.caption)
                    .foregroundStyle(LiquidGlassStyle.tertiaryText)

                HStack {
                    Spacer()
                    Button("닫기") { dismiss() }
                        .buttonStyle(LiquidGlassPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
        .frame(width: 500, height: 520)
    }

    private func guideStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(LiquidGlassStyle.deepSky.opacity(0.75))
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(LiquidGlassStyle.bodyText)
        }
    }
}
