import AppKit
import Foundation

/// bloomie 친구 공유 — 사용자가 공유 버튼을 눌렀을 때만 동작.
/// 히스토리 전체 공유는 절대 불가. 현재 활동만 공유.
@MainActor
enum BloomieShareHelper {
    private static let bloomieURLScheme = "bloomie"
    private static let bloomieShareHost = "share"
    private static let bloomieBundleIDs = ["com.example.chatApp", "com.bloomie.app"]

    struct SharePayload: Sendable {
        let appName: String
        let windowTitle: String
        let category: ActivityCategory
        let focusRatioToday: Double
    }

    enum ShareResult: Sendable {
        case openedBloomie(URL)
        case copiedToClipboardFallback(String)
        case failed(String)
    }

    static func shareCurrentActivity(
        _ payload: SharePayload,
        composeMessage: String? = nil
    ) -> ShareResult {
        let sanitizedApp = SecureInputValidator.sanitizeAppName(payload.appName)
        let sanitizedTitle = SecureInputValidator.sanitizeWindowTitle(payload.windowTitle)
        let senderName = BloomieMessageFormatter.defaultSenderName

        guard !sanitizedApp.isEmpty else {
            return .failed("공유할 활동이 없습니다.")
        }

        guard SecureInputValidator.isAllowedCustomURLScheme(bloomieURLScheme) else {
            return .failed("허용되지 않은 공유 방식입니다.")
        }

        guard let url = buildShareURL(
            appName: sanitizedApp,
            windowTitle: sanitizedTitle,
            category: payload.category,
            focusRatio: payload.focusRatioToday,
            from: senderName
        ) else {
            return .failed("공유 URL을 생성할 수 없습니다.")
        }

        let clipboardText = buildClipboardFallback(
            appName: sanitizedApp,
            windowTitle: sanitizedTitle,
            category: payload.category,
            focusRatio: payload.focusRatioToday,
            url: url,
            composeMessage: composeMessage
        )

        if isBloomieAvailable() {
            if let composeMessage, !composeMessage.isEmpty {
                SecureClipboard.copyEphemeral(clipboardText)
            }
            NSWorkspace.shared.open(url)
            return .openedBloomie(url)
        }

        SecureClipboard.copyEphemeral(clipboardText)
        openBloomieAppFallback(with: url)
        return .copiedToClipboardFallback(clipboardText)
    }

    static func buildShareURL(
        appName: String,
        windowTitle: String,
        category: ActivityCategory,
        focusRatio: Double,
        from: String? = nil
    ) -> URL? {
        var components = URLComponents()
        components.scheme = bloomieURLScheme
        components.host = bloomieShareHost

        var queryItems = [
            URLQueryItem(name: "app", value: appName),
            URLQueryItem(name: "title", value: windowTitle),
            URLQueryItem(name: "category", value: category.bloomieCategoryLabel),
            URLQueryItem(name: "focus", value: String(format: "%.0f", min(max(focusRatio, 0), 1) * 100))
        ]

        if let from, !from.isEmpty {
            queryItems.append(URLQueryItem(name: "from", value: from))
        }

        components.queryItems = queryItems

        guard let url = components.url, url.scheme?.lowercased() == bloomieURLScheme else {
            return nil
        }
        return url
    }

    private static func isBloomieAvailable() -> Bool {
        for bundleID in bloomieBundleIDs {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
                return true
            }
        }
        guard let url = URL(string: "\(bloomieURLScheme)://") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    private static func openBloomieAppFallback(with shareURL: URL) {
        if NSWorkspace.shared.open(shareURL) {
            return
        }

        for bundleID in bloomieBundleIDs {
            if let bloomieAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = [shareURL.absoluteString]
                NSWorkspace.shared.openApplication(at: bloomieAppURL, configuration: config)
                return
            }
        }

        if let url = URL(string: "\(bloomieURLScheme)://") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func buildClipboardFallback(
        appName: String,
        windowTitle: String,
        category: ActivityCategory,
        focusRatio: Double,
        url: URL,
        composeMessage: String? = nil
    ) -> String {
        var text = """
        🌸 bloomie 공유
        """

        if let composeMessage, !composeMessage.isEmpty {
            text += "\n\(composeMessage)\n"
        }

        text += """

        앱: \(appName)
        창: \(windowTitle.isEmpty ? "(제목 없음)" : windowTitle)
        카테고리: \(category.bloomieCategoryLabel)
        오늘 집중: \(Int(min(max(focusRatio, 0), 1) * 100))%

        \(url.absoluteString)

        bloomie 채팅에 붙여넣어 보내세요. (60초 후 클립보드에서 자동 삭제)
        """
        return text
    }
}
