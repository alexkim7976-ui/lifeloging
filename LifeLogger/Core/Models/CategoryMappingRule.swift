import Foundation
import SwiftData

@Model
final class CategoryMappingRule {
    var id: UUID
    var pattern: String
    var matchTarget: String
    var categoryRaw: String
    var priority: Int

    var category: ActivityCategory {
        get { ActivityCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        pattern: String,
        matchTarget: String = "both",
        category: ActivityCategory,
        priority: Int = 0
    ) {
        self.id = id
        self.pattern = pattern
        self.matchTarget = matchTarget
        self.categoryRaw = category.rawValue
        self.priority = priority
    }
}
