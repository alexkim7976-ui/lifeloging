import AppKit
import Foundation

/// macOS에 설치된 카카오톡·Instagram 등으로 메시지 공유
@MainActor
enum SocialAppShareService {
    enum SocialApp: String, CaseIterable, Identifiable {
        case kakaoTalk
        case instagram

        var id: String { rawValue }

        var title: String {
            switch self {
            case .kakaoTalk: return "카카오톡으로 보내기"
            case .instagram: return "Instagram 웹으로 보내기"
            }
        }

        var shortName: String {
            switch self {
            case .kakaoTalk: return "카카오톡"
            case .instagram: return "Instagram"
            }
        }

        var systemImage: String {
            switch self {
            case .kakaoTalk: return "bubble.left.and.bubble.right.fill"
            case .instagram: return "camera.fill"
            }
        }

        var bundleIdentifiers: [String] {
            switch self {
            case .kakaoTalk:
                return ["com.kakao.KakaoTalkMac", "com.kakao.KakaoTalk"]
            case .instagram:
                return ["com.burbn.instagram", "com.instagram.android"]
            }
        }

        var applicationNames: [String] {
            switch self {
            case .kakaoTalk: return ["KakaoTalk", "카카오톡"]
            case .instagram: return ["Instagram"]
            }
        }

        /// Instagram은 앱 설치 여부와 관계없이 웹 공유를 제공합니다.
        var isAlwaysAvailable: Bool {
            switch self {
            case .instagram: return true
            case .kakaoTalk: return false
            }
        }
    }

    enum ShareResult: Sendable {
        case opened(SocialApp)
        case failed(String)
    }

    private static let instagramWebURLs: [URL] = [
        URL(string: "https://www.instagram.com/direct/inbox/")!,
        URL(string: "https://www.instagram.com/")!
    ]

    static func installedApps() -> [SocialApp] {
        SocialApp.allCases.filter { $0.isAlwaysAvailable || isInstalled($0) }
    }

    static func isInstalled(_ app: SocialApp) -> Bool {
        if app.isAlwaysAvailable { return true }
        return applicationURL(for: app) != nil
    }

    static func share(text: String, via app: SocialApp) -> ShareResult {
        switch app {
        case .instagram:
            return shareViaInstagramWeb(text: text)
        case .kakaoTalk:
            return shareViaNativeApp(text: text, app: app)
        }
    }

    static func shareViaInstagramWeb(text: String) -> ShareResult {
        let sanitized = SecureInputValidator.sanitizeText(text, maxLength: 2000)
        guard !sanitized.isEmpty else {
            return .failed("보낼 메시지가 없습니다.")
        }

        SecureClipboard.copyEphemeral(sanitized)

        for url in instagramWebURLs {
            if NSWorkspace.shared.open(url) {
                return .opened(.instagram)
            }
        }

        return .failed("Instagram 웹사이트를 열 수 없습니다.")
    }

    static func successMessage(for app: SocialApp, friendName: String?) -> String {
        switch app {
        case .instagram:
            return "Instagram 웹 DM을 열었습니다. 붙여넣기(Cmd+V)로 메시지와 링크를 보내세요."
        case .kakaoTalk:
            let target = friendName.map { "\($0)에게 " } ?? ""
            return "카카오톡을 열었습니다. \(target)보낼 메시지를 붙여넣어 전송하세요."
        }
    }

    private static func shareViaNativeApp(text: String, app: SocialApp) -> ShareResult {
        let sanitized = SecureInputValidator.sanitizeText(text, maxLength: 2000)
        guard !sanitized.isEmpty else {
            return .failed("보낼 메시지가 없습니다.")
        }
        guard let appURL = applicationURL(for: app) else {
            return .failed("\(app.shortName) 앱을 찾을 수 없습니다.")
        }

        SecureClipboard.copyEphemeral(sanitized)

        guard NSWorkspace.shared.open(appURL) else {
            return .failed("\(app.shortName) 앱을 열 수 없습니다.")
        }
        return .opened(app)
    }

    private static func applicationURL(for app: SocialApp) -> URL? {
        for bundleID in app.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return url
            }
        }

        let searchPaths = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        for directory in searchPaths {
            for name in app.applicationNames {
                let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).app")
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }

        return nil
    }
}
