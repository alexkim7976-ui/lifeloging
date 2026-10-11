import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageStore = AppLanguageStore.shared

    var isRequired: Bool = false
    @State private var draftLanguage = AppLanguage.english

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 22) {
                LiquidGlassSectionHeader(
                    title: pickerTitle,
                    systemImage: "globe"
                )

                Text(pickerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(AppLanguage.userSelectableCases) { language in
                        languageButton(language)
                    }
                }

                Button(languageButtonTitle) {
                    AppLanguageStore.shared.setLanguage(draftLanguage)
                    dismiss()
                }
                .buttonStyle(LiquidGlassPrimaryButtonStyle())
            }
            .padding(32)
            .frame(width: 520)
        }
        .onAppear {
            if languageStore.hasUserSelectedLanguage {
                draftLanguage = languageStore.language
            } else {
                // Clean install: preselect the detected system language (English on EN Macs).
                draftLanguage = AppLanguage.detectSystemLanguage()
            }
        }
    }

    private var pickerTitle: String {
        languageStore.hasUserSelectedLanguage
            ? L10n.tr("settings.language.title")
            : L10n.tr("settings.language.firstRunTitle")
    }

    private var pickerSubtitle: String {
        languageStore.hasUserSelectedLanguage
            ? L10n.tr("settings.language.subtitle")
            : L10n.tr("settings.language.firstRunSubtitle")
    }

    private var languageButtonTitle: String {
        languageStore.hasUserSelectedLanguage
            ? L10n.tr("common.apply")
            : L10n.tr("settings.language.continue")
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        Button {
            draftLanguage = language
        } label: {
            Text(language.nativeName)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(
                    draftLanguage == language
                        ? LiquidGlassStyle.titleText
                        : LiquidGlassStyle.secondaryText
                )
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            draftLanguage == language
                                ? LiquidGlassStyle.aquaGlow.opacity(0.35)
                                : Color.white.opacity(0.08)
                        )
                }
        }
        .buttonStyle(.plain)
    }
}
