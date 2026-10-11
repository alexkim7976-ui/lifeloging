import Foundation
import SwiftData

@MainActor
enum MessengerRepository {
    static func bootstrap(context: ModelContext) {
        ensureBotFriend(context: context)
        migrateLegacyStoreIfNeeded(context: context)
        try? context.save()
    }

    static func friends(context: ModelContext, includeHidden: Bool = false) -> [MessengerFriend] {
        let descriptor = FetchDescriptor<MessengerFriend>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        if includeHidden { return all }
        return all.filter { !$0.hiddenFromInbox }
    }

    static func friend(id: UUID, context: ModelContext) -> MessengerFriend? {
        var descriptor = FetchDescriptor<MessengerFriend>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func friend(remoteUserId: String, context: ModelContext) -> MessengerFriend? {
        var descriptor = FetchDescriptor<MessengerFriend>(
            predicate: #Predicate { $0.remoteUserId == remoteUserId }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    static func upsertCloudFriend(
        remoteUserId: String,
        nickname: String,
        context: ModelContext
    ) -> MessengerFriend {
        if remoteUserId == MessengerBot.remoteUserId {
            ensureBotFriend(context: context)
            if let bot = friend(id: MessengerBot.friendID, context: context) {
                bot.remoteUserId = MessengerBot.remoteUserId
                bot.nickname = nickname
                bot.hiddenFromInbox = false
                return bot
            }
        }

        if let existing = friend(remoteUserId: remoteUserId, context: context) {
            existing.nickname = SecureInputValidator.sanitizeAppName(nickname)
            existing.hiddenFromInbox = false
            return existing
        }

        let sanitizedName = SecureInputValidator.sanitizeAppName(nickname)
        let friend = MessengerFriend(
            nickname: sanitizedName,
            displayID: remoteUserId,
            remoteUserId: remoteUserId
        )
        context.insert(friend)
        ensureRoom(for: friend, context: context)
        return friend
    }

    @discardableResult
    static func insertSyncedMessage(
        friendID: UUID,
        text: String,
        messageType: String,
        isOutgoing: Bool,
        sentAt: Date,
        isRead: Bool,
        remoteDocumentId: String,
        context: ModelContext
    ) -> MessengerMessage? {
        if let existing = message(remoteDocumentId: remoteDocumentId, context: context) {
            existing.isRead = isRead
            return nil
        }

        let message = MessengerMessage(
            friendID: friendID,
            text: text,
            messageType: messageType,
            isOutgoing: isOutgoing,
            sentAt: sentAt,
            isRead: isRead,
            remoteDocumentId: remoteDocumentId
        )
        context.insert(message)
        bumpInteraction(for: friendID, by: 1, context: context)
        return message
    }

    static func bumpInteractionOnly(for friendID: UUID, context: ModelContext) {
        updateTheme(for: friendID, context: context)
    }

    private static func message(remoteDocumentId: String, context: ModelContext) -> MessengerMessage? {
        var descriptor = FetchDescriptor<MessengerMessage>(
            predicate: #Predicate { $0.remoteDocumentId == remoteDocumentId }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func addFriend(displayID: String, nickname: String, context: ModelContext) -> MessengerFriend? {
        let sanitizedID = SecureInputValidator.sanitizeCategoryPattern(displayID) ?? SecureInputValidator.sanitizeAppName(displayID)
        let sanitizedName = SecureInputValidator.sanitizeAppName(nickname)
        guard !sanitizedID.isEmpty, !sanitizedName.isEmpty else { return nil }

        if let existing = friends(context: context, includeHidden: true).first(where: {
            $0.displayID.caseInsensitiveCompare(sanitizedID) == .orderedSame
        }) {
            existing.hiddenFromInbox = false
            return existing
        }

        let friend = MessengerFriend(nickname: sanitizedName, displayID: sanitizedID)
        context.insert(friend)
        ensureRoom(for: friend, context: context)
        try? context.save()
        return friend
    }

    static func removeFriend(_ friend: MessengerFriend, context: ModelContext) {
        deleteMessages(for: friend.id, context: context)
        deleteRoom(for: friend.id, context: context)
        context.delete(friend)
        try? context.save()
    }

    static func hideChat(_ friend: MessengerFriend, context: ModelContext) {
        friend.hiddenFromInbox = true
        try? context.save()
    }

    static func messages(for friendID: UUID, context: ModelContext) -> [MessengerMessage] {
        let descriptor = FetchDescriptor<MessengerMessage>(
            predicate: #Predicate { $0.friendID == friendID },
            sortBy: [SortDescriptor(\.sentAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func latestMessage(for friendID: UUID, context: ModelContext) -> MessengerMessage? {
        var descriptor = FetchDescriptor<MessengerMessage>(
            predicate: #Predicate { $0.friendID == friendID },
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    static func sendMessage(
        to friend: MessengerFriend,
        text: String,
        type: String = "text",
        context: ModelContext
    ) -> MessengerMessage? {
        let sanitized = SecureInputValidator.sanitizeText(text, maxLength: 500)
        guard !sanitized.isEmpty else { return nil }

        let message = MessengerMessage(
            friendID: friend.id,
            text: sanitized,
            messageType: type,
            isOutgoing: true,
            isRead: true
        )
        context.insert(message)
        friend.hiddenFromInbox = false
        bumpInteraction(for: friend.id, by: 1, context: context)
        try? context.save()

        if friend.isBot, friend.remoteUserId == nil {
            appendBotReply(to: friend, userText: sanitized, context: context)
        } else if friend.remoteUserId == MessengerBot.remoteUserId {
            // Cloud bot replies come from Firestore listener.
        } else if friend.remoteUserId == nil {
            appendBotReply(to: friend, userText: sanitized, context: context)
        }
        return message
    }

    static func receiveIncomingMessage(
        from senderName: String,
        text: String,
        type: String = "text",
        context: ModelContext
    ) -> MessengerFriend? {
        let displayID = SecureInputValidator.sanitizeAppName(senderName).lowercased()
        let friend = addFriend(displayID: displayID.isEmpty ? "friend" : displayID, nickname: senderName, context: context)
            ?? friends(context: context, includeHidden: true).first

        guard let friend else { return nil }

        let sanitized = SecureInputValidator.sanitizeText(text, maxLength: 500)
        guard !sanitized.isEmpty else { return friend }

        let message = MessengerMessage(
            friendID: friend.id,
            text: sanitized,
            messageType: type,
            isOutgoing: false,
            isRead: false
        )
        context.insert(message)
        friend.hiddenFromInbox = false
        bumpInteraction(for: friend.id, by: 1, context: context)
        try? context.save()
        return friend
    }

    static func receiveActivityShare(
        from senderName: String,
        share: LifeLoggerShareHelper.FriendActivityShare,
        context: ModelContext
    ) -> MessengerFriend? {
        let text = BloomieMessageFormatter.buildIncomingPrefill(from: share, senderName: senderName)
        return receiveIncomingMessage(from: senderName, text: text, type: "activity", context: context)
    }

    static func markRead(friendID: UUID, context: ModelContext) {
        let unread = messages(for: friendID, context: context).filter { !$0.isOutgoing && !$0.isRead }
        unread.forEach { $0.isRead = true }
        try? context.save()
    }

    static func room(for friendID: UUID, context: ModelContext) -> MessengerRoom? {
        var descriptor = FetchDescriptor<MessengerRoom>(
            predicate: #Predicate { $0.friendID == friendID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func interactionScore(for friendID: UUID, context: ModelContext) -> Int {
        room(for: friendID, context: context)?.interactionScore ?? 0
    }

    static func themeMode(for friendID: UUID, context: ModelContext) -> MessengerThemeMode {
        let raw = room(for: friendID, context: context)?.themeMode ?? MessengerThemeMode.cozy.rawValue
        return MessengerThemeMode(rawValue: raw) ?? .cozy
    }

    private static func ensureBotFriend(context: ModelContext) {
        if friend(id: MessengerBot.friendID, context: context) != nil { return }

        let bot = MessengerFriend(
            id: MessengerBot.friendID,
            nickname: MessengerBot.nickname,
            displayID: MessengerBot.displayID,
            isBot: true,
            remoteUserId: MessengerBot.remoteUserId
        )
        context.insert(bot)
        ensureRoom(for: bot, context: context)

        if messages(for: bot.id, context: context).isEmpty {
            let welcome = MessengerMessage(
                friendID: bot.id,
                text: "안녕! 나는 LifeLogger야. 지금 뭐 하고 있는지 공유하거나 집중에 대해 물어봐 🌸",
                messageType: "system",
                isOutgoing: false,
                isRead: false
            )
            context.insert(welcome)
        }
    }

    private static func ensureRoom(for friend: MessengerFriend, context: ModelContext) {
        guard room(for: friend.id, context: context) == nil else { return }
        context.insert(MessengerRoom(friendID: friend.id))
    }

    private static func bumpInteraction(for friendID: UUID, by amount: Int, context: ModelContext) {
        let room = room(for: friendID, context: context) ?? {
            let created = MessengerRoom(friendID: friendID)
            context.insert(created)
            return created
        }()
        if amount > 0 {
            room.interactionScore = min(room.interactionScore + amount, 999)
        }
        updateTheme(for: friendID, context: context)
    }

    private static func updateTheme(for friendID: UUID, context: ModelContext) {
        guard let room = room(for: friendID, context: context) else { return }
        let score = room.interactionScore
        room.themeMode = switch score {
        case 0..<5: MessengerThemeMode.cozy.rawValue
        case 5..<15: MessengerThemeMode.warm.rawValue
        case 15..<40: MessengerThemeMode.deep.rawValue
        default: MessengerThemeMode.chilly.rawValue
        }
    }

    private static func appendBotReply(to friend: MessengerFriend, userText: String, context: ModelContext) {
        let reply: String
        if userText.contains("집중") || userText.contains("몰입") {
            reply = "좋아! 짧은 뽀모도로로 시작해보는 건 어때? 🍅"
        } else if userText.contains("공유") {
            reply = "활동을 친구에게 보낼 땐 메시지를 확인한 뒤 직접 전송해줘."
        } else {
            reply = "응, 계속 기록하고 있어. 필요하면 친구 탭에서 메시지를 보내봐!"
        }

        let message = MessengerMessage(
            friendID: friend.id,
            text: reply,
            messageType: "text",
            isOutgoing: false,
            isRead: false
        )
        context.insert(message)
        try? context.save()
    }

    private static func deleteMessages(for friendID: UUID, context: ModelContext) {
        messages(for: friendID, context: context).forEach { context.delete($0) }
    }

    private static func deleteRoom(for friendID: UUID, context: ModelContext) {
        if let room = room(for: friendID, context: context) {
            context.delete(room)
        }
    }

    private static let migrationKey = "lifelogger.messenger.migrated.v1"

    private static func migrateLegacyStoreIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let existingNonBot = friends(context: context, includeHidden: true).filter { !$0.isBot }
        if !existingNonBot.isEmpty {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let store = FriendMessageStore.shared
        store.reload()
        guard !store.friends.isEmpty else { return }

        for legacyFriend in store.friends {
            let displayID = legacyFriend.nickname.lowercased()
            guard let friend = addFriend(
                displayID: displayID,
                nickname: legacyFriend.nickname,
                context: context
            ) else { continue }

            for legacyMessage in store.messages(for: legacyFriend).reversed() {
                let message = MessengerMessage(
                    id: legacyMessage.id,
                    friendID: friend.id,
                    text: legacyMessage.text,
                    messageType: "text",
                    isOutgoing: legacyMessage.isOutgoing,
                    sentAt: legacyMessage.sentAt,
                    isRead: true
                )
                context.insert(message)
            }
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
