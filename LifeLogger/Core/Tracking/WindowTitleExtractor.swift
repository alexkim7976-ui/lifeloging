import AppKit
import ApplicationServices

/// Accessibility API를 통해 활성 창의 제목을 추출합니다.
/// 손쉬운 사용 권한이 필요합니다.
@MainActor
final class WindowTitleExtractor {
    static let shared = WindowTitleExtractor()

    private init() {}

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 손쉬운 사용 권한이 없을 때 시스템 안내를 **한 번만** 표시합니다.
    func requestAccessibilityPermissionIfNeeded() {
        guard !isAccessibilityTrusted else { return }

        let promptKey = "lifelogger.didPromptAccessibility"
        guard !UserDefaults.standard.bool(forKey: promptKey) else { return }

        UserDefaults.standard.set(true, forKey: promptKey)
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// 현재 전면 앱의 활성 창 제목을 반환합니다.
    func activeWindowTitle(for app: NSRunningApplication? = NSWorkspace.shared.frontmostApplication) -> String {
        guard let app, let pid = app.processIdentifier as pid_t? else {
            return ""
        }

        guard isAccessibilityTrusted else {
            return ""
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        if windowResult == .success, let window = focusedWindow {
            if let title = copyStringAttribute(from: window as! AXUIElement, attribute: kAXTitleAttribute) {
                return title
            }
        }

        var windowList: AnyObject?
        let listResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowList
        )

        guard listResult == .success,
              let windows = windowList as? [AXUIElement],
              let firstWindow = windows.first else {
            return ""
        }

        return copyStringAttribute(from: firstWindow, attribute: kAXTitleAttribute) ?? ""
    }

    private func copyStringAttribute(from element: AXUIElement, attribute: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let string = value as? String else {
            return nil
        }
        return string
    }
}

// MARK: - Sensitive Window Masking (#15)

enum SensitiveWindowMasking {
    private static let appsKey = "lifelogger.masking.apps"
    private static let keywordsKey = "lifelogger.masking.keywords"

    static let defaultBlockedApps = [
        "1Password", "Bitwarden", "KeePassXC", "Keychain Access", "Safari Private"
    ]
    static let defaultBlockedKeywords = [
        "password", "비밀번호", "secret", "private browsing", "시크릿"
    ]

    static var blockedAppNames: [String] {
        get {
            let custom = UserDefaults.standard.stringArray(forKey: appsKey) ?? []
            return custom.isEmpty ? defaultBlockedApps : custom
        }
        set { UserDefaults.standard.set(SecureInputValidator.sanitizeAppNameList(newValue), forKey: appsKey) }
    }

    static var blockedKeywords: [String] {
        get {
            let custom = UserDefaults.standard.stringArray(forKey: keywordsKey) ?? []
            return custom.isEmpty ? defaultBlockedKeywords : custom
        }
        set { UserDefaults.standard.set(SecureInputValidator.sanitizeKeywordList(newValue), forKey: keywordsKey) }
    }

    struct SanitizedWindow: Sendable {
        let windowTitle: String
        let wasRedacted: Bool
    }

    static func sanitize(appName: String, windowTitle: String) -> SanitizedWindow {
        let lowerApp = appName.lowercased()
        let lowerTitle = windowTitle.lowercased()

        let appBlocked = blockedAppNames.contains { rule in
            let r = rule.lowercased()
            return lowerApp.contains(r) || r.contains(lowerApp)
        }
        let keywordBlocked = blockedKeywords.contains { lowerTitle.contains($0.lowercased()) }

        if appBlocked || keywordBlocked {
            return SanitizedWindow(windowTitle: "[민감 정보 마스킹]", wasRedacted: true)
        }
        return SanitizedWindow(windowTitle: windowTitle, wasRedacted: false)
    }
}
