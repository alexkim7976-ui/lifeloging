import AppKit
import Foundation

/// 민감 공유 데이터 클립보드 자동 삭제
@MainActor
enum SecureClipboard {
    private static var clearTask: Task<Void, Never>?

    static func copyEphemeral(_ text: String, clearAfter seconds: TimeInterval = 45) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        clearTask?.cancel()
        clearTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if pasteboard.string(forType: .string) == text {
                    pasteboard.clearContents()
                }
            }
        }
    }
}
