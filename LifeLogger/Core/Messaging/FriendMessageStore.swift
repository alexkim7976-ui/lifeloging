import Foundation

struct FriendContact: Codable, Identifiable, Equatable {
    let id: UUID
    var nickname: String
    let createdAt: Date

    init(id: UUID = UUID(), nickname: String, createdAt: Date = Date()) {
        self.id = id
        self.nickname = nickname
        self.createdAt = createdAt
    }
}

struct StoredMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let friendID: UUID
    let text: String
    let sentAt: Date
    let isOutgoing: Bool

    init(
        id: UUID = UUID(),
        friendID: UUID,
        text: String,
        sentAt: Date = Date(),
        isOutgoing: Bool = true
    ) {
        self.id = id
        self.friendID = friendID
        self.text = text
        self.sentAt = sentAt
        self.isOutgoing = isOutgoing
    }
}

@MainActor
final class FriendMessageStore: ObservableObject {
    static let shared = FriendMessageStore()

    @Published private(set) var friends: [FriendContact] = []
    @Published private(set) var messages: [StoredMessage] = []

    var senderDisplayName: String? {
        get { defaults.string(forKey: Keys.senderName) }
        set {
            let sanitized = newValue.flatMap { SecureInputValidator.sanitizeAppName($0) }
            if let sanitized, !sanitized.isEmpty {
                defaults.set(sanitized, forKey: Keys.senderName)
            } else {
                defaults.removeObject(forKey: Keys.senderName)
            }
        }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let friends = "lifelogger.friends.v1"
        static let messages = "lifelogger.messages.v1"
        static let senderName = "lifelogger.senderName"
    }

    private init() {
        load()
    }

    func reload() {
        load()
    }

    func addFriend(nickname: String) -> FriendContact? {
        let sanitized = SecureInputValidator.sanitizeAppName(nickname)
        guard !sanitized.isEmpty else { return nil }
        guard !friends.contains(where: { $0.nickname.caseInsensitiveCompare(sanitized) == .orderedSame }) else {
            return friends.first { $0.nickname.caseInsensitiveCompare(sanitized) == .orderedSame }
        }

        let friend = FriendContact(nickname: sanitized)
        friends.insert(friend, at: 0)
        persist()
        return friend
    }

    func removeFriend(_ friend: FriendContact) {
        friends.removeAll { $0.id == friend.id }
        messages.removeAll { $0.friendID == friend.id }
        persist()
    }

    @discardableResult
    func appendMessage(to friend: FriendContact, text: String, isOutgoing: Bool = true) -> StoredMessage? {
        let sanitized = SecureInputValidator.sanitizeText(text, maxLength: 500)
        guard !sanitized.isEmpty else { return nil }

        let message = StoredMessage(friendID: friend.id, text: sanitized, isOutgoing: isOutgoing)
        messages.insert(message, at: 0)
        persist()
        return message
    }

    func messages(for friend: FriendContact) -> [StoredMessage] {
        messages
            .filter { $0.friendID == friend.id }
            .sorted { $0.sentAt > $1.sentAt }
    }

    func latestMessage(for friend: FriendContact) -> StoredMessage? {
        messages(for: friend).first
    }

    private func load() {
        friends = decode([FriendContact].self, forKey: Keys.friends) ?? []
        messages = decode([StoredMessage].self, forKey: Keys.messages) ?? []
    }

    private func persist() {
        encode(friends, forKey: Keys.friends)
        encode(messages, forKey: Keys.messages)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
