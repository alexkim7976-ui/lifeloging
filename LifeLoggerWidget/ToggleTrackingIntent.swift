import AppIntents
import WidgetKit

struct ToggleTrackingIntent: AppIntent {
    static let title: LocalizedStringResource = "트래킹 토글"
    static let description = IntentDescription("LifeLogger 활동 추적을 켜거나 끕니다.")

    func perform() async throws -> some IntentResult {
        let defaults = AppGroupConstants.sharedDefaults
        let currentlyEnabled = defaults.bool(forKey: AppGroupConstants.Keys.isTrackingEnabled)
        defaults.set(!currentlyEnabled, forKey: AppGroupConstants.Keys.isTrackingEnabled)
        SecureAppGroupWriter.audit()

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct LifeLoggerWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "LifeLogger 위젯"
}
