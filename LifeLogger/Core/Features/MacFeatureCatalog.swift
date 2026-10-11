import Foundation
import AppKit

enum MacFeatureStatus: String, Codable, Sendable, CaseIterable {
    case implemented
    case partial
    case planned

    @MainActor
    var label: String {
        switch self {
        case .implemented: return L10n.tr("features.status.implemented")
        case .partial: return L10n.tr("features.status.partial")
        case .planned: return L10n.tr("features.status.planned")
        }
    }
}

struct MacFeature: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let index: Int
    let categoryId: String
    let categoryName: String
    let title: String
    let status: MacFeatureStatus
}

struct MacFeatureCatalogPayload: Codable, Sendable {
    let version: Int
    let features: [MacFeature]
}

enum MacFeatureCatalog {
    static let totalCount = 500

    static func loadFeatures() -> [MacFeature] {
        guard let url = Bundle.main.url(forResource: "mac_features", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(MacFeatureCatalogPayload.self, from: data) else {
            return []
        }
        return payload.features.sorted { $0.index < $1.index }
    }

    static func categories(from features: [MacFeature]) -> [(id: String, name: String, count: Int)] {
        var seen: [String: String] = [:]
        var counts: [String: Int] = [:]
        for feature in features {
            seen[feature.categoryId] = feature.categoryName
            counts[feature.categoryId, default: 0] += 1
        }
        return seen.keys.sorted().map { id in
            (id: id, name: seen[id] ?? id, count: counts[id] ?? 0)
        }
    }

    static func summary(from features: [MacFeature]) -> (implemented: Int, partial: Int, planned: Int) {
        var implemented = 0
        var partial = 0
        var planned = 0
        for feature in features {
            switch feature.status {
            case .implemented: implemented += 1
            case .partial: partial += 1
            case .planned: planned += 1
            }
        }
        return (implemented, partial, planned)
    }

    static func exportCSV(features: [MacFeature]) -> String {
        var lines = ["index,id,category,title,status"]
        for feature in features {
            let title = feature.title.replacingOccurrences(of: "\"", with: "\"\"")
            lines.append("\(feature.index),\(feature.id),\(feature.categoryName),\"\(title)\",\(feature.status.rawValue)")
        }
        return lines.joined(separator: "\n")
    }
}

enum MacFeatureBookmarks {
    private static let key = "lifelogger.featureBookmarks"

    static func isBookmarked(_ id: String) -> Bool {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? []).contains(id)
    }

    static func toggle(_ id: String) {
        var set = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        UserDefaults.standard.set(Array(set), forKey: key)
    }

    static func bookmarkedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
}

enum DockFocusBadge {
    nonisolated(unsafe) static var lastPercent = 0

    @MainActor
    static func update(focusRatio: Double) {
        let percent = Int(min(max(focusRatio, 0), 1) * 100)
        lastPercent = percent
        NSApp.dockTile.badgeLabel = percent > 0 ? "\(percent)" : nil
        NSApp.dockTile.display()
    }
}
