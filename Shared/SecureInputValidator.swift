import Foundation

/// 사용자 입력·외부 공유 데이터 검증
enum SecureInputValidator {
    static let maxAppNameLength = 80
    static let maxWindowTitleLength = 200
    static let maxCategoryPatternLength = 64

    static func sanitizeAppName(_ value: String) -> String {
        sanitizeText(value, maxLength: maxAppNameLength)
    }

    static func sanitizeWindowTitle(_ value: String) -> String {
        sanitizeText(value, maxLength: maxWindowTitleLength)
    }

    static func sanitizeCategoryPattern(_ value: String) -> String? {
        let sanitized = sanitizeText(value, maxLength: maxCategoryPatternLength)
        guard !sanitized.isEmpty else { return nil }
        guard !sanitized.contains("/"), !sanitized.contains("\\") else { return nil }
        guard !sanitized.contains("..") else { return nil }
        return sanitized
    }

    static func sanitizeText(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
                && scalar.value != 0
        }
        let cleaned = String(String.UnicodeScalarView(filtered))
        if cleaned.count <= maxLength { return cleaned }
        return String(cleaned.prefix(maxLength))
    }

    static func sanitizeAppNameList(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let sanitized = sanitizeAppName(value)
            guard !sanitized.isEmpty else { return nil }
            let key = sanitized.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return sanitized
        }
    }

    static func sanitizeKeywordList(_ values: [String]) -> [String] {
        sanitizeAppNameList(values)
    }

    static func isAllowedCustomURLScheme(_ scheme: String) -> Bool {
        let allowed = Set(["bloomie", "lifelogger"])
        return allowed.contains(scheme.lowercased())
    }
}
