import Foundation

@MainActor
extension ActivityCategory {
    var localizedName: String {
        switch self {
        case .coding: return L10n.tr("category.coding")
        case .design: return L10n.tr("category.design")
        case .writing: return L10n.tr("category.writing")
        case .communication: return L10n.tr("category.communication")
        case .browsing: return L10n.tr("category.browsing")
        case .entertainment: return L10n.tr("category.entertainment")
        case .other: return L10n.tr("category.other")
        }
    }

    var localizedBloomieLabel: String {
        switch self {
        case .browsing: return L10n.tr("category.browsing")
        default: return localizedName
        }
    }
}
