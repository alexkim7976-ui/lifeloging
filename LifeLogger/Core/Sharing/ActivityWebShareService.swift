import Foundation

/// 브라우저에서 열 수 있는 공개 활동 공유 링크
enum ActivityWebShareService {
    static let sharePageBaseURL = "https://my-chat-app-4182e.web.app/share/"

    static func buildWebShareURL(
        from snapshot: CurrentActivitySnapshot,
        senderName: String? = nil
    ) -> URL? {
        guard snapshot.canShare else { return nil }

        var components = URLComponents(string: sharePageBaseURL)
        var queryItems = [
            URLQueryItem(name: "app", value: snapshot.appName),
            URLQueryItem(name: "title", value: snapshot.windowTitle),
            URLQueryItem(name: "cat", value: snapshot.category.rawValue),
            URLQueryItem(
                name: "focus",
                value: String(Int(min(max(snapshot.focusRatioToday, 0), 1) * 100))
            ),
            URLQueryItem(name: "elapsed", value: String(snapshot.segmentElapsedSeconds)),
            URLQueryItem(name: "ts", value: String(Int(Date().timeIntervalSince1970)))
        ]

        let sender = SecureInputValidator.sanitizeAppName(senderName ?? BloomieMessageFormatter.defaultSenderName)
        if !sender.isEmpty {
            queryItems.append(URLQueryItem(name: "from", value: sender))
        }

        if let goal = snapshot.goalLabel {
            queryItems.append(URLQueryItem(name: "goal", value: goal))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    static func buildShareText(
        message: String,
        snapshot: CurrentActivitySnapshot,
        senderName: String? = nil
    ) -> String {
        let trimmed = SecureInputValidator.sanitizeText(message, maxLength: 500)
        let body = BloomieMessageFormatter.buildDeliveryBody(message: trimmed, snapshot: snapshot)

        guard let url = buildWebShareURL(from: snapshot, senderName: senderName) else {
            return body
        }

        return """
        \(body)

        🔗 지금 하는 일 보기: \(url.absoluteString)
        """
    }

    @MainActor
    @discardableResult
    static func copyWebShareLink(
        from snapshot: CurrentActivitySnapshot,
        senderName: String?
    ) -> String? {
        guard let url = buildWebShareURL(from: snapshot, senderName: senderName) else {
            return nil
        }

        let status = BloomieMessageFormatter.buildStatusLine(from: snapshot)
        var clipboardText = """
        \(status)
        """
        if let goal = snapshot.goalLabel {
            clipboardText += "\n🎯 오늘 목표: \(goal)"
        }
        clipboardText += "\n\n🔗 \(url.absoluteString)"
        SecureClipboard.copyEphemeral(clipboardText)
        return url.absoluteString
    }
}
