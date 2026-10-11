import Foundation

/// bloomie 채팅과 동일한 메시지 형식 생성
enum BloomieMessageFormatter {
    private static let maxPrefillLength = 240

    static var defaultSenderName: String {
        if let saved = UserDefaults.standard.string(forKey: "lifelogger.senderName"),
           !saved.isEmpty {
            return SecureInputValidator.sanitizeAppName(saved)
        }
        return Host.current().localizedName ?? "나"
    }

    static func buildStatusLine(from snapshot: CurrentActivitySnapshot) -> String {
        let verb = "\(snapshot.category.bloomieCategoryLabel) 중"
        if snapshot.windowTitle.isEmpty {
            return "지금 \(snapshot.appName) \(verb)"
        }
        return "지금 \(snapshot.appName) \(verb) — \(snapshot.windowTitle)"
    }

    static func buildOutgoingPrefill(from snapshot: CurrentActivitySnapshot, senderName: String? = nil) -> String {
        let name = SecureInputValidator.sanitizeAppName(senderName ?? defaultSenderName)
        let status = buildStatusLine(from: snapshot)
        return clamp("[\(name) 님이 공유] \(status)")
    }

    static func buildIncomingPrefill(
        from share: LifeLoggerShareHelper.FriendActivityShare,
        senderName: String
    ) -> String {
        let name = SecureInputValidator.sanitizeAppName(senderName)
        let verb = "\(share.category.bloomieCategoryLabel) 중"
        let status = share.windowTitle.isEmpty
            ? "지금 \(share.appName) \(verb)"
            : "지금 \(share.appName) \(verb) — \(share.windowTitle)"
        return clamp("[\(name) 님이 공유(미확인)] \(status)")
    }

    static func buildDeliveryBody(message: String, snapshot: CurrentActivitySnapshot) -> String {
        var lines = [
            message,
            "",
            "📍 LifeLogger",
            "오늘 집중: \(snapshot.focusPercentLabel) · 이 활동: \(snapshot.elapsedLabel)"
        ]

        if let goal = snapshot.goalLabel {
            lines.append("🎯 오늘 목표: \(goal)")
        }

        return lines.joined(separator: "\n")
    }

    private static func clamp(_ value: String) -> String {
        if value.count <= maxPrefillLength { return value }
        return String(value.prefix(maxPrefillLength))
    }
}
