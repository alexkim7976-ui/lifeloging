import AppKit
import Sparkle

/// Sparkle 자동 업데이트 (#2) — Developer ID 배포용
@MainActor
final class SparkleUpdaterController: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    /// EdDSA 공개키가 실제 값으로 채워졌는지 여부.
    /// placeholder 상태에서는 Sparkle 업데이터를 시작하지 않아
    /// "The updater failed to start" 오류 팝업을 막는다.
    private let isConfigured: Bool

    init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let configured = !key.isEmpty && !key.hasPrefix("REPLACE_")
        isConfigured = configured

        updaterController = SPUStandardUpdaterController(
            startingUpdater: configured,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        if !configured {
            AppLogger.updates.info("Sparkle updater not started: SUPublicEDKey is not configured yet")
        }
    }

    func checkForUpdates() {
        guard isConfigured else {
            AppLogger.updates.info("Manual update check skipped: updater not configured")
            return
        }
        AppLogger.updates.info("Manual update check requested")
        updaterController.checkForUpdates(nil)
    }
}
