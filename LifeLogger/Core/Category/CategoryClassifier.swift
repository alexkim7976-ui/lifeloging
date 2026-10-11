import Foundation
import SwiftData

@MainActor
final class CategoryClassifier {
    static let shared = CategoryClassifier()

    private let defaultRules: [(pattern: String, category: ActivityCategory)] = [
        ("xcode", .coding), ("cursor", .coding), ("visual studio", .coding),
        ("intellij", .coding), ("terminal", .coding), ("iterm", .coding),
        ("github", .coding), ("vscode", .coding), ("code", .coding),
        ("figma", .design), ("sketch", .design), ("photoshop", .design),
        ("illustrator", .design), ("affinity", .design), ("canva", .design),
        ("notion", .writing), ("pages", .writing), ("word", .writing),
        ("google docs", .writing), ("obsidian", .writing), ("bear", .writing),
        ("slack", .communication), ("discord", .communication), ("teams", .communication),
        ("zoom", .communication), ("mail", .communication), ("messages", .communication),
        ("kakao", .communication), ("telegram", .communication),
        ("safari", .browsing), ("chrome", .browsing), ("firefox", .browsing),
        ("arc", .browsing), ("edge", .browsing), ("brave", .browsing),
        ("youtube", .entertainment), ("netflix", .entertainment), ("spotify", .entertainment),
        ("steam", .entertainment), ("tv", .entertainment), ("music", .entertainment)
    ]

    private init() {}

    func classify(appName: String, windowTitle: String, customRules: [CategoryMappingRule] = []) -> ActivityCategory {
        let appLower = appName.lowercased()
        let titleLower = windowTitle.lowercased()

        let sortedCustom = customRules.sorted { $0.priority > $1.priority }
        for rule in sortedCustom {
            let pattern = rule.pattern.lowercased()
            switch rule.matchTarget {
            case "app":
                if appLower.contains(pattern) { return rule.category }
            case "title":
                if titleLower.contains(pattern) { return rule.category }
            default:
                if appLower.contains(pattern) || titleLower.contains(pattern) {
                    return rule.category
                }
            }
        }

        for rule in defaultRules {
            if appLower.contains(rule.pattern) || titleLower.contains(rule.pattern) {
                return rule.category
            }
        }

        return .other
    }
}
