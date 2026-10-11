import Foundation

/// App Group에는 **집계 통계만** 기록. 원시 창 제목·세gment 데이터는 절대 저장하지 않음.
enum SecureAppGroupWriter {
    private static let allowedKeys: Set<String> = [
        AppGroupConstants.Keys.isTrackingEnabled,
        AppGroupConstants.Keys.todayFocusRatio,
        AppGroupConstants.Keys.todayTotalSeconds,
        AppGroupConstants.Keys.todayFocusSeconds,
        AppGroupConstants.Keys.lastSevenDayFocusRatios,
        AppGroupConstants.Keys.currentAppName,
        AppGroupConstants.Keys.currentSegmentStart,
        AppGroupConstants.Keys.pomodoroPhase,
        AppGroupConstants.Keys.pomodoroRemainingSeconds
    ]

    /// 위젯 공유 영역에 금지된 키 (원시 활동 데이터 유출 방지)
    private static let forbiddenKeyFragments = [
        "windowTitle", "window_title", "segment", "history", "raw", "payload", "clipboard"
    ]

    static func write(_ stats: SharedStatistics) {
        purgeForbiddenKeys()

        let defaults = AppGroupConstants.sharedDefaults
        defaults.set(stats.isTrackingEnabled, forKey: AppGroupConstants.Keys.isTrackingEnabled)
        defaults.set(clampRatio(stats.todayFocusRatio), forKey: AppGroupConstants.Keys.todayFocusRatio)
        defaults.set(max(0, stats.todayTotalSeconds), forKey: AppGroupConstants.Keys.todayTotalSeconds)
        defaults.set(max(0, stats.todayFocusSeconds), forKey: AppGroupConstants.Keys.todayFocusSeconds)
        defaults.set(sanitizeRatios(stats.lastSevenDayFocusRatios), forKey: AppGroupConstants.Keys.lastSevenDayFocusRatios)

        if let appName = stats.currentAppName {
            defaults.set(SecureInputValidator.sanitizeAppName(appName), forKey: AppGroupConstants.Keys.currentAppName)
        } else {
            defaults.removeObject(forKey: AppGroupConstants.Keys.currentAppName)
        }

        if let start = stats.currentSegmentStart {
            defaults.set(start.timeIntervalSince1970, forKey: AppGroupConstants.Keys.currentSegmentStart)
        } else {
            defaults.removeObject(forKey: AppGroupConstants.Keys.currentSegmentStart)
        }
    }

    static func audit() {
        purgeForbiddenKeys()
        removeKeysOutsideAllowlist()
    }

    private static func purgeForbiddenKeys() {
        let defaults = AppGroupConstants.sharedDefaults
        for key in defaults.dictionaryRepresentation().keys {
            let lower = key.lowercased()
            if forbiddenKeyFragments.contains(where: { lower.contains($0) }) {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static func removeKeysOutsideAllowlist() {
        let defaults = AppGroupConstants.sharedDefaults
        for key in defaults.dictionaryRepresentation().keys where !allowedKeys.contains(key) {
            defaults.removeObject(forKey: key)
        }
    }

    private static func clampRatio(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func sanitizeRatios(_ values: [Double]) -> [Double] {
        Array(values.prefix(7)).map { clampRatio($0) }
    }

    static func writePomodoro(phase: String, remainingSeconds: Int) {
        audit()
        let defaults = AppGroupConstants.sharedDefaults
        defaults.set(SecureInputValidator.sanitizeText(phase, maxLength: 32), forKey: AppGroupConstants.Keys.pomodoroPhase)
        defaults.set(max(0, remainingSeconds), forKey: AppGroupConstants.Keys.pomodoroRemainingSeconds)
    }
}
