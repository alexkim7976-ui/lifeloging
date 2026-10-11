import Combine
import Foundation

extension Notification.Name {
    static let lifeloggerLanguageDidChange = Notification.Name("lifeloggerLanguageDidChange")
}

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    case korean = "ko"
    case spanish = "es"
    case hindi = "hi"
    case arabic = "ar"
    case portuguese = "pt"
    case russian = "ru"
    case german = "de"

    var id: String { rawValue }

    static var userSelectableCases: [AppLanguage] {
        allCases
    }

    var locale: Locale {
        switch self {
        case .system:
            return Locale(identifier: Self.detectSystemLanguage().rawValue)
        default:
            return Locale(identifier: rawValue)
        }
    }

    var layoutDirection: LayoutDirection {
        effectiveLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    var effectiveLanguage: AppLanguage {
        self == .system ? Self.detectSystemLanguage() : self
    }

    /// Always shown in the language itself (picker labels).
    @MainActor
    var nativeName: String {
        switch self {
        case .system: return L10n.tr("settings.language.system")
        case .english: return "English"
        case .chinese: return "中文"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .hindi: return "हिन्दी"
        case .arabic: return "العربية"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        case .german: return "Deutsch"
        }
    }

    static func detectSystemLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        let lower = preferred.lowercased()
        if lower.hasPrefix("ko") { return .korean }
        if lower.hasPrefix("zh") { return .chinese }
        if lower.hasPrefix("es") { return .spanish }
        if lower.hasPrefix("hi") { return .hindi }
        if lower.hasPrefix("ar") { return .arabic }
        if lower.hasPrefix("pt") { return .portuguese }
        if lower.hasPrefix("ru") { return .russian }
        if lower.hasPrefix("de") { return .german }
        return .english
    }
}

enum LayoutDirection {
    case leftToRight
    case rightToLeft
}

@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()

    private static let storageKey = "lifelogger.appLanguage"
    private static let selectionCompletedKey = "lifelogger.appLanguage.selected"

    @Published private(set) var language: AppLanguage
    @Published private(set) var hasUserSelectedLanguage: Bool

    private var localeObserver: NSObjectProtocol?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
            hasUserSelectedLanguage = true
            if !UserDefaults.standard.bool(forKey: Self.selectionCompletedKey) {
                UserDefaults.standard.set(true, forKey: Self.selectionCompletedKey)
            }
        } else {
            language = .system
            hasUserSelectedLanguage = UserDefaults.standard.bool(forKey: Self.selectionCompletedKey)
        }

        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemLocaleDidChange()
            }
        }
    }

    var effectiveLanguage: AppLanguage {
        language.effectiveLanguage
    }

    var needsLanguageSelection: Bool {
        !hasUserSelectedLanguage
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language || !hasUserSelectedLanguage else { return }
        self.language = language
        hasUserSelectedLanguage = true
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        UserDefaults.standard.set(true, forKey: Self.selectionCompletedKey)
        broadcastLanguageChange()
    }

    private func handleSystemLocaleDidChange() {
        guard language == .system else { return }
        broadcastLanguageChange()
    }

    private func broadcastLanguageChange() {
        objectWillChange.send()
        NotificationCenter.default.post(name: .lifeloggerLanguageDidChange, object: nil)
    }
}
