import Foundation
import SwiftData

@Model
final class ActivitySegment {
    var id: UUID
    var appName: String
    var windowTitle: String
    var categoryRaw: String
    var startTime: Date
    var endTime: Date?
    var isAFK: Bool
    /// 사용자가 수동으로 지정한 카테고리 (옵션)
    var userCategoryRaw: String?
    /// 프로젝트/태그
    var tag: String?
    /// 메모
    var note: String?

    var category: ActivityCategory {
        get { ActivityCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// 통계·딥워크 등에 사용 — userCategoryRaw 우선
    var effectiveCategory: ActivityCategory {
        if let raw = userCategoryRaw, let override = ActivityCategory(rawValue: raw) {
            return override
        }
        return category
    }

    var effectiveTag: String? {
        let trimmed = tag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : SecureInputValidator.sanitizeText(trimmed, maxLength: 40)
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return max(0, end.timeIntervalSince(startTime))
    }

    init(
        id: UUID = UUID(),
        appName: String,
        windowTitle: String,
        category: ActivityCategory,
        startTime: Date = Date(),
        endTime: Date? = nil,
        isAFK: Bool = false,
        userCategoryRaw: String? = nil,
        tag: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.appName = appName
        self.windowTitle = windowTitle
        self.categoryRaw = category.rawValue
        self.startTime = startTime
        self.endTime = endTime
        self.isAFK = isAFK
        self.userCategoryRaw = userCategoryRaw
        self.tag = tag
        self.note = note
    }
}
