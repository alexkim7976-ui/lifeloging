import Foundation

/// LifeLogger 친구 공유 — lifelogger:// 딥링크로 친구에게 현재 활동 전달
enum LifeLoggerShareHelper {
    private static let scheme = "lifelogger"
    private static let shareHost = "share"

    struct FriendActivityShare: Sendable, Equatable {
        let appName: String
        let windowTitle: String
        let category: ActivityCategory
        let focusPercent: Int
        let elapsedSeconds: Int
    }

    static func buildShareURL(from snapshot: CurrentActivitySnapshot) -> URL? {
        guard snapshot.canShare else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = shareHost
        var queryItems = [
            URLQueryItem(name: "app", value: snapshot.appName),
            URLQueryItem(name: "title", value: snapshot.windowTitle),
            URLQueryItem(name: "category", value: snapshot.category.rawValue),
            URLQueryItem(name: "focus", value: String(format: "%.0f", min(max(snapshot.focusRatioToday, 0), 1) * 100)),
            URLQueryItem(name: "elapsed", value: String(snapshot.segmentElapsedSeconds))
        ]

        if let goal = snapshot.goalLabel {
            queryItems.append(URLQueryItem(name: "goal", value: goal))
        }

        components.queryItems = queryItems

        guard let url = components.url, url.scheme?.lowercased() == scheme else {
            return nil
        }
        return url
    }

    static func buildFriendShareText(from snapshot: CurrentActivitySnapshot) -> String {
        guard snapshot.canShare else {
            return "지금 공유할 활동이 없습니다."
        }

        let windowLine = snapshot.windowTitle.isEmpty
            ? "작업: (제목 없음)"
            : "작업: \(snapshot.windowTitle)"

        var text = """
        👋 LifeLogger 친구 공유
        지금 나는 이렇게 집중 중이에요!

        앱: \(snapshot.appName)
        \(windowLine)
        카테고리: \(snapshot.category.rawValue)
        이 활동: \(snapshot.elapsedLabel)
        오늘 집중: \(snapshot.focusPercentLabel)
        """

        if let goal = snapshot.goalLabel {
            text += "\n오늘 목표: \(goal)"
        }

        if let webURL = ActivityWebShareService.buildWebShareURL(from: snapshot) {
            text += "\n\n🔗 \(webURL.absoluteString)"
            text += "\n(브라우저에서 지금 하는 일 보기)"
        } else if let url = buildShareURL(from: snapshot) {
            text += "\n\n🔗 \(url.absoluteString)"
            text += "\n(LifeLogger 앱으로 열기)"
        }

        return text
    }

    static func parseShareURL(_ url: URL) -> FriendActivityShare? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == shareHost else {
            return nil
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        let values = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        let appName = SecureInputValidator.sanitizeAppName(values["app"] ?? "")
        guard !appName.isEmpty else { return nil }

        let windowTitle = SecureInputValidator.sanitizeWindowTitle(values["title"] ?? "")
        let categoryRaw = values["category"] ?? ActivityCategory.other.rawValue
        let category = ActivityCategory(rawValue: categoryRaw) ?? .other
        let focusPercent = min(max(Int(values["focus"] ?? "0") ?? 0, 0), 100)
        let elapsedSeconds = max(0, Int(values["elapsed"] ?? "0") ?? 0)

        return FriendActivityShare(
            appName: appName,
            windowTitle: windowTitle,
            category: category,
            focusPercent: focusPercent,
            elapsedSeconds: elapsedSeconds
        )
    }
}
