import Foundation

enum ActivityCategory: String, Codable, CaseIterable, Sendable {
    case coding = "코딩"
    case design = "디자인"
    case writing = "문서·글쓰기"
    case communication = "커뮤니케이션"
    case browsing = "브라우징"
    case entertainment = "엔터테인먼트"
    case other = "기타"

    var isFocusCategory: Bool {
        switch self {
        case .coding, .design, .writing:
            return true
        case .communication, .browsing, .entertainment, .other:
            return false
        }
    }

    var systemImage: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintbrush"
        case .writing: return "doc.text"
        case .communication: return "bubble.left.and.bubble.right"
        case .browsing: return "safari"
        case .entertainment: return "play.tv"
        case .other: return "ellipsis.circle"
        }
    }

    var accentHex: String {
        switch self {
        case .coding: return "6BA8F0"
        case .design: return "B889EE"
        case .writing: return "58CFA0"
        case .communication: return "F0B45A"
        case .browsing: return "56C4EA"
        case .entertainment: return "F07882"
        case .other: return "94A8BC"
        }
    }

    /// bloomie ShareLinkParser 화이트리스트와 동일한 라벨
    var bloomieCategoryLabel: String {
        switch self {
        case .browsing: return "리서치·브라우징"
        default: return rawValue
        }
    }
}
