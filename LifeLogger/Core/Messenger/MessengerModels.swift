import Foundation
import SwiftData

@Model
final class MessengerFriend {
    @Attribute(.unique) var id: UUID
    var nickname: String
    var displayID: String
    var isBot: Bool
    var createdAt: Date
    var hiddenFromInbox: Bool
    var remoteUserId: String?

    init(
        id: UUID = UUID(),
        nickname: String,
        displayID: String,
        isBot: Bool = false,
        createdAt: Date = Date(),
        hiddenFromInbox: Bool = false,
        remoteUserId: String? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.displayID = displayID
        self.isBot = isBot
        self.createdAt = createdAt
        self.hiddenFromInbox = hiddenFromInbox
        self.remoteUserId = remoteUserId
    }
}

@Model
final class MessengerMessage {
    @Attribute(.unique) var id: UUID
    var friendID: UUID
    var text: String
    var messageType: String
    var isOutgoing: Bool
    var sentAt: Date
    var isRead: Bool
    var reaction: String?
    var remoteDocumentId: String?

    init(
        id: UUID = UUID(),
        friendID: UUID,
        text: String,
        messageType: String = "text",
        isOutgoing: Bool,
        sentAt: Date = Date(),
        isRead: Bool = false,
        reaction: String? = nil,
        remoteDocumentId: String? = nil
    ) {
        self.id = id
        self.friendID = friendID
        self.text = text
        self.messageType = messageType
        self.isOutgoing = isOutgoing
        self.sentAt = sentAt
        self.isRead = isRead
        self.reaction = reaction
        self.remoteDocumentId = remoteDocumentId
    }
}

@Model
final class MessengerRoom {
    @Attribute(.unique) var friendID: UUID
    var themeMode: String
    var interactionScore: Int

    init(friendID: UUID, themeMode: String = "cozy", interactionScore: Int = 0) {
        self.friendID = friendID
        self.themeMode = themeMode
        self.interactionScore = interactionScore
    }
}

enum MessengerThemeMode: String, CaseIterable, Identifiable {
    case cozy
    case warm
    case deep
    case chilly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cozy: return "Cozy"
        case .warm: return "Warm"
        case .deep: return "Deep"
        case .chilly: return "Chilly"
        }
    }
}

enum MessengerBot {
    static let friendID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let displayID = "lifelogger_bot"
    static let remoteUserId = "bloomie_bot"
    static let nickname = "LifeLogger"
}
