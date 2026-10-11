import Foundation

struct SharedStatistics: Codable, Sendable {
    var todayFocusRatio: Double
    var todayTotalSeconds: TimeInterval
    var todayFocusSeconds: TimeInterval
    var lastSevenDayFocusRatios: [Double]
    var isTrackingEnabled: Bool
    var currentAppName: String?
    var currentSegmentStart: Date?

    static let empty = SharedStatistics(
        todayFocusRatio: 0,
        todayTotalSeconds: 0,
        todayFocusSeconds: 0,
        lastSevenDayFocusRatios: Array(repeating: 0, count: 7),
        isTrackingEnabled: false,
        currentAppName: nil,
        currentSegmentStart: nil
    )

    func writeToAppGroup() {
        SecureAppGroupWriter.write(self)
    }

    static func readFromAppGroup() -> SharedStatistics {
        SecureAppGroupWriter.audit()
        let defaults = AppGroupConstants.sharedDefaults
        return SharedStatistics(
            todayFocusRatio: defaults.double(forKey: AppGroupConstants.Keys.todayFocusRatio),
            todayTotalSeconds: defaults.double(forKey: AppGroupConstants.Keys.todayTotalSeconds),
            todayFocusSeconds: defaults.double(forKey: AppGroupConstants.Keys.todayFocusSeconds),
            lastSevenDayFocusRatios: defaults.array(forKey: AppGroupConstants.Keys.lastSevenDayFocusRatios) as? [Double]
                ?? Array(repeating: 0, count: 7),
            isTrackingEnabled: defaults.bool(forKey: AppGroupConstants.Keys.isTrackingEnabled),
            currentAppName: defaults.string(forKey: AppGroupConstants.Keys.currentAppName).map {
                SecureInputValidator.sanitizeAppName($0)
            },
            currentSegmentStart: {
                let value = defaults.double(forKey: AppGroupConstants.Keys.currentSegmentStart)
                return value > 0 ? Date(timeIntervalSince1970: value) : nil
            }()
        )
    }
}
