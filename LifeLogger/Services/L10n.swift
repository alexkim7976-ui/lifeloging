import Foundation
import SwiftUI

enum L10n {
    @MainActor
    static func tr(_ key: String) -> String {
        trUnlocked(key, languageCode: AppLanguageStore.shared.effectiveLanguage.rawValue)
    }

    @MainActor
    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), arguments: arguments)
    }

    /// Safe for `LocalizedError` and other nonisolated call sites.
    /// Falls back to English (never Korean) when a translation is missing.
    nonisolated static func trUnlocked(_ key: String, languageCode: String? = nil) -> String {
        let language = languageCode ?? resolvedLanguageCode()
        if let value = L10nCatalog.table[key]?[language] {
            return value
        }
        if let english = L10nCatalog.table[key]?[AppLanguage.english.rawValue] {
            return english
        }
        return key
    }

    nonisolated static func trUnlocked(_ key: String, _ arguments: CVarArg..., languageCode: String? = nil) -> String {
        String(format: trUnlocked(key, languageCode: languageCode), arguments: arguments)
    }

    nonisolated private static func resolvedLanguageCode() -> String {
        let raw = UserDefaults.standard.string(forKey: "lifelogger.appLanguage") ?? AppLanguage.system.rawValue
        if raw == AppLanguage.system.rawValue {
            return AppLanguage.detectSystemLanguage().rawValue
        }
        return AppLanguage(rawValue: raw)?.rawValue ?? AppLanguage.english.rawValue
    }
}

struct L10nText: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let key: String

    var body: some View {
        Text(L10n.tr(key))
            .id(languageStore.language.rawValue)
    }
}

extension View {
    func localizedRefresh() -> some View {
        modifier(LocalizedRefreshModifier())
    }
}

/// Applies reactive locale + layout direction from `AppLanguageStore`.
struct AppLanguageRoot<Content: View>: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .localizedRefresh()
            .environment(\.locale, languageStore.effectiveLanguage.locale)
            .id(languageStore.language.rawValue)
    }
}

private struct LocalizedRefreshModifier: ViewModifier {
    @ObservedObject private var languageStore = AppLanguageStore.shared

    func body(content: Content) -> some View {
        content
            .environment(
                \.layoutDirection,
                languageStore.effectiveLanguage.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
            )
            .environment(\.locale, languageStore.effectiveLanguage.locale)
            .id(languageStore.language.rawValue)
    }
}
