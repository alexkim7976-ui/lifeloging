import Foundation
import SwiftData

@MainActor
final class CategoryMappingStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllRules() -> [CategoryMappingRule] {
        let descriptor = FetchDescriptor<CategoryMappingRule>(
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func addRule(pattern: String, matchTarget: String = "both", category: ActivityCategory, priority: Int = 10) {
        guard let sanitized = SecureInputValidator.sanitizeCategoryPattern(pattern) else { return }
        let rule = CategoryMappingRule(
            pattern: sanitized,
            matchTarget: matchTarget,
            category: category,
            priority: priority
        )
        modelContext.insert(rule)
        try? modelContext.save()
        SecurityBootstrap.runAfterPersistenceWrite()
    }

    func deleteRule(_ rule: CategoryMappingRule) {
        modelContext.delete(rule)
        try? modelContext.save()
        SecurityBootstrap.runAfterPersistenceWrite()
    }
}
