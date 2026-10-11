import Foundation

enum AppGroupConstants {
    static let suiteName = "group.com.lifelogger.taehyeon"

    enum Keys {
        static let isTrackingEnabled = "isTrackingEnabled"
        static let todayFocusRatio = "todayFocusRatio"
        static let todayTotalSeconds = "todayTotalSeconds"
        static let todayFocusSeconds = "todayFocusSeconds"
        static let lastSevenDayFocusRatios = "lastSevenDayFocusRatios"
        static let currentAppName = "currentAppName"
        static let currentSegmentStart = "currentSegmentStart"
        static let pomodoroPhase = "pomodoroPhase"
        static let pomodoroRemainingSeconds = "pomodoroRemainingSeconds"
    }

    static var sharedDefaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("App Group '\(suiteName)' is not configured.")
        }
        return defaults
    }
}
