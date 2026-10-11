import Foundation

enum FeatureMetricsStore {
    private static var defaults: UserDefaults { AppGroupConstants.sharedDefaults }
    private static let prefix = "lifelogger.feature."

    static func increment(_ key: String, by value: Double = 1) {
        let k = prefix + "counter." + key
        defaults.set(defaults.double(forKey: k) + value, forKey: k)
    }

    static func counter(_ key: String) -> Double {
        defaults.double(forKey: prefix + "counter." + key)
    }

    static func addTime(_ key: String, seconds: TimeInterval) {
        let k = prefix + "time." + key
        defaults.set(defaults.double(forKey: k) + max(0, seconds), forKey: k)
    }

    static func time(_ key: String) -> TimeInterval {
        defaults.double(forKey: prefix + "time." + key)
    }

    static func setBool(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: prefix + "bool." + key)
    }

    static func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        let k = prefix + "bool." + key
        guard defaults.object(forKey: k) != nil else { return defaultValue }
        return defaults.bool(forKey: k)
    }

    static func setString(_ key: String, _ value: String) {
        defaults.set(value, forKey: prefix + "string." + key)
    }

    static func string(_ key: String, default defaultValue: String = "") -> String {
        defaults.string(forKey: prefix + "string." + key) ?? defaultValue
    }

    static func setInt(_ key: String, _ value: Int) {
        defaults.set(value, forKey: prefix + "int." + key)
    }

    static func int(_ key: String, default defaultValue: Int = 0) -> Int {
        guard defaults.object(forKey: prefix + "int." + key) != nil else { return defaultValue }
        return defaults.integer(forKey: prefix + "int." + key)
    }

    static func setDate(_ key: String, _ value: Date) {
        defaults.set(value.timeIntervalSince1970, forKey: prefix + "date." + key)
    }

    static func date(_ key: String) -> Date? {
        let k = prefix + "date." + key
        guard defaults.object(forKey: k) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: k))
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(total)s"
    }

    static func formatCount(_ value: Double) -> String {
        if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        if value == floor(value) { return String(Int(value)) }
        return String(format: "%.1f", value)
    }
}
