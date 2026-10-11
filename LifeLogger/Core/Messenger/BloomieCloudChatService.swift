import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftData

struct BloomieUserProfile {
    let uid: String
    let displayId: String
    let name: String
}

@MainActor
final class BloomieCloudChatService: ObservableObject {
    static let shared = BloomieCloudChatService()

    @Published private(set) var syncingFriends = false
    @Published private(set) var inboxRevision = UUID()
    @Published var lastError: String?

    private let db = Firestore.firestore()
    private var listeners: [UUID: ListenerRegistration] = [:]
    private var inboxSyncUID: String?

    private init() {}

    private func notifyInboxChanged() {
        inboxRevision = UUID()
    }

    func chatRoomId(myUID: String, friendUID: String) -> String {
        [myUID, friendUID].sorted().joined(separator: "_")
    }

    func createUserDocument(uid: String, displayId: String, nickname: String) async throws {
        try await db.collection("users").document(uid).setData([
            "uid": uid,
            "displayId": displayId,
            "email": "\(displayId)@bloomie.local",
            "name": nickname,
            "friends": [
                ["id": MessengerBot.remoteUserId, "name": "Bloomie (AI)"]
            ],
            "hiddenChats": [],
            "blockedUsers": [],
            "fcmToken": "",
            "profileImage": NSNull(),
            "notificationsEnabled": true,
            "language": "ko",
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchUserProfile(uid: String) async -> BloomieUserProfile? {
        do {
            let snapshot = try await db.collection("users").document(uid).getDocument()
            guard let data = snapshot.data(),
                  let displayId = data["displayId"] as? String,
                  let name = data["name"] as? String else { return nil }
            return BloomieUserProfile(uid: uid, displayId: displayId, name: name)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func syncFriends(uid: String, context: ModelContext) async {
        syncingFriends = true
        defer { syncingFriends = false }

        do {
            let snapshot = try await db.collection("users").document(uid).getDocument()
            guard let friends = snapshot.data()?["friends"] as? [[String: Any]] else { return }

            for entry in friends {
                guard let remoteId = entry["id"] as? String,
                      let name = entry["name"] as? String else { continue }
                _ = MessengerRepository.upsertCloudFriend(
                    remoteUserId: remoteId,
                    nickname: name,
                    context: context
                )
            }
            try? context.save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 앱 실행 중 모든 클라우드 친구 채팅을 실시간 수신 (bloomie처럼)
    func startInboxSync(myUID: String, context: ModelContext) {
        if inboxSyncUID == myUID, !listeners.isEmpty { return }
        inboxSyncUID = myUID

        Task(priority: .utility) {
            await syncFriends(uid: myUID, context: context)
            await MainActor.run {
                refreshInboxListeners(myUID: myUID, context: context)
            }
        }
    }

    func refreshInboxSyncIfNeeded() {
        guard let uid = inboxSyncUID else { return }
        let context = MessengerModelContainer.mainContext
        Task {
            await syncFriends(uid: uid, context: context)
            refreshInboxListeners(myUID: uid, context: context)
        }
    }

    func stopInboxSync() {
        stopAllListeners()
        inboxSyncUID = nil
    }

    private func refreshInboxListeners(myUID: String, context: ModelContext) {
        let cloudFriends = MessengerRepository.friends(context: context)
            .filter { $0.remoteUserId != nil }

        let activeIDs = Set(cloudFriends.map(\.id))
        for friendID in listeners.keys where !activeIDs.contains(friendID) {
            stopListening(friendID: friendID)
        }

        for friend in cloudFriends where listeners[friend.id] == nil {
            startListening(friend: friend, myUID: myUID, context: context) { [weak self] in
                self?.notifyInboxChanged()
            }
        }
    }

    func addFriendByDisplayId(
        _ targetDisplayId: String,
        alias: String,
        myUID: String,
        myDisplayName: String? = nil,
        context: ModelContext
    ) async throws -> MessengerFriend {
        let sanitizedTarget = targetDisplayId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sanitizedAlias = SecureInputValidator.sanitizeAppName(alias)
        guard !sanitizedTarget.isEmpty, !sanitizedAlias.isEmpty else {
            throw BloomieCloudAuthError.emptyFields
        }

        if sanitizedTarget == "bloomie" || sanitizedTarget == MessengerBot.displayID {
            try await db.collection("users").document(myUID).updateData([
                "friends": FieldValue.arrayUnion([
                    ["id": MessengerBot.remoteUserId, "name": "Bloomie (AI)"]
                ])
            ])
            let friend = MessengerRepository.upsertCloudFriend(
                remoteUserId: MessengerBot.remoteUserId,
                nickname: "Bloomie (AI)",
                context: context
            )
            try? context.save()
            return friend
        }

        let query = try await db.collection("users")
            .whereField("displayId", isEqualTo: sanitizedTarget)
            .getDocuments()

        guard let friendDoc = query.documents.first else {
            throw BloomieCloudAuthError.underlying("해당 아이디의 사용자를 찾을 수 없습니다.")
        }
        guard friendDoc.documentID != myUID else {
            throw BloomieCloudAuthError.underlying("자기 자신은 친구로 추가할 수 없습니다.")
        }

        try await db.collection("users").document(myUID).updateData([
            "friends": FieldValue.arrayUnion([
                ["id": friendDoc.documentID, "name": sanitizedAlias]
            ])
        ])

        let resolvedMyName: String
        if let myDisplayName, !myDisplayName.isEmpty {
            resolvedMyName = myDisplayName
        } else if let profile = await fetchUserProfile(uid: myUID) {
            resolvedMyName = profile.name
        } else {
            resolvedMyName = "LifeLogger"
        }
        try await db.collection("users").document(friendDoc.documentID).setData([
            "friends": FieldValue.arrayUnion([
                ["id": myUID, "name": resolvedMyName]
            ])
        ], merge: true)

        let friend = MessengerRepository.upsertCloudFriend(
            remoteUserId: friendDoc.documentID,
            nickname: sanitizedAlias,
            context: context
        )
        try? context.save()
        if listeners[friend.id] == nil {
            refreshInboxListeners(myUID: myUID, context: context)
        } else {
            notifyInboxChanged()
        }
        return friend
    }

    func startListening(
        friend: MessengerFriend,
        myUID: String,
        context: ModelContext,
        onUpdate: @escaping () -> Void
    ) {
        guard let remoteUserId = friend.remoteUserId else { return }
        stopListening(friendID: friend.id)

        let roomId = chatRoomId(myUID: myUID, friendUID: remoteUserId)
        let listener = db.collection("chats")
            .document(roomId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: 50)
            .addSnapshotListener { snapshot, error in
                if let error {
                    Task { @MainActor in
                        self.lastError = error.localizedDescription
                    }
                    return
                }

                guard let snapshot else { return }
                let documents: [QueryDocumentSnapshot]
                if snapshot.documentChanges.isEmpty {
                    documents = snapshot.documents
                } else {
                    documents = snapshot.documentChanges
                        .filter { $0.type == .added || $0.type == .modified }
                        .map(\.document)
                }
                guard !documents.isEmpty else { return }

                Task { @MainActor in
                    await self.mergeRemoteMessages(
                        documents: documents,
                        friend: friend,
                        myUID: myUID,
                        context: context
                    )
                    onUpdate()
                }
            }

        listeners[friend.id] = listener
    }

    func stopListening(friendID: UUID) {
        listeners[friendID]?.remove()
        listeners[friendID] = nil
    }

    func stopAllListeners() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }

    func markReadInCloud(friend: MessengerFriend, myUID: String, context: ModelContext) async {
        guard let remoteUserId = friend.remoteUserId else { return }
        let roomId = chatRoomId(myUID: myUID, friendUID: remoteUserId)
        let unread = MessengerRepository.messages(for: friend.id, context: context)
            .filter { !$0.isOutgoing && !$0.isRead }

        for message in unread {
            guard let docId = message.remoteDocumentId else { continue }
            try? await db.collection("chats")
                .document(roomId)
                .collection("messages")
                .document(docId)
                .updateData(["isRead": true])
        }
    }

    func sendActivityShare(
        message: String,
        snapshot: CurrentActivitySnapshot,
        to friend: MessengerFriend,
        myUID: String,
        context: ModelContext
    ) async throws {
        var text = SecureInputValidator.sanitizeText(message, maxLength: 500)
        guard !text.isEmpty else { return }

        if let shareURL = ActivityWebShareService.buildWebShareURL(from: snapshot) {
            let suffix = "\n\n\(shareURL.absoluteString)"
            if text.count + suffix.count <= 500 {
                text += suffix
            }
        }

        try await postMessage(
            text: text,
            type: "activity",
            to: friend,
            myUID: myUID,
            context: context
        )
    }

    func sendText(
        _ text: String,
        to friend: MessengerFriend,
        myUID: String,
        context: ModelContext
    ) async throws {
        let sanitized = SecureInputValidator.sanitizeText(text, maxLength: 500)
        guard !sanitized.isEmpty else { return }
        try await postMessage(
            text: sanitized,
            type: "text",
            to: friend,
            myUID: myUID,
            context: context
        )
    }

    private func postMessage(
        text: String,
        type: String,
        to friend: MessengerFriend,
        myUID: String,
        context: ModelContext
    ) async throws {
        guard let remoteUserId = friend.remoteUserId else {
            throw BloomieCloudAuthError.underlying("클라우드 친구가 아닙니다. bloomie 계정으로 친구를 추가해주세요.")
        }

        let roomId = chatRoomId(myUID: myUID, friendUID: remoteUserId)

        try await db.collection("users").document(myUID).updateData([
            "hiddenChats": FieldValue.arrayRemove([remoteUserId])
        ])

        try await db.collection("chats").document(roomId).setData([
            "participants": [myUID, remoteUserId].sorted(),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)

        let document = try await db.collection("chats")
            .document(roomId)
            .collection("messages")
            .addDocument(data: [
                "senderId": myUID,
                "text": text,
                "type": type,
                "reaction": NSNull(),
                "timestamp": FieldValue.serverTimestamp(),
                "isRead": false
            ])

        MessengerRepository.insertSyncedMessage(
            friendID: friend.id,
            text: text,
            messageType: type,
            isOutgoing: true,
            sentAt: Date(),
            isRead: true,
            remoteDocumentId: document.documentID,
            context: context
        )
        friend.hiddenFromInbox = false
        MessengerRepository.bumpInteractionOnly(for: friend.id, context: context)
        try? context.save()
        notifyInboxChanged()
    }

    private func ensureFriendExists(remoteUserId: String, context: ModelContext) async {
        guard MessengerRepository.friend(remoteUserId: remoteUserId, context: context) == nil else { return }
        let profile = await fetchUserProfile(uid: remoteUserId)
        let name = profile?.name ?? profile?.displayId ?? "친구"
        _ = MessengerRepository.upsertCloudFriend(
            remoteUserId: remoteUserId,
            nickname: name,
            context: context
        )
        try? context.save()
    }

    private func mergeRemoteMessages(
        documents: [QueryDocumentSnapshot],
        friend: MessengerFriend,
        myUID: String,
        context: ModelContext
    ) async {
        for document in documents {
            let data = document.data()
            guard let senderId = data["senderId"] as? String else { continue }

            if senderId != myUID {
                await ensureFriendExists(remoteUserId: senderId, context: context)
            }

            let type = data["type"] as? String ?? "text"
            let text: String
            switch type {
            case "text", "activity":
                text = data["text"] as? String ?? ""
            case "location":
                text = "📍 위치를 공유했습니다"
            case "image":
                text = "📷 사진을 보냈습니다"
            case "appointment":
                text = "📅 약속 초대"
            default:
                text = data["text"] as? String ?? ""
            }

            let sanitized = SecureInputValidator.sanitizeText(text, maxLength: 500)
            guard !sanitized.isEmpty else { continue }

            let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let isOutgoing = senderId == myUID
            let isRead = isOutgoing || (data["isRead"] as? Bool ?? false)
            let targetFriendID: UUID
            if isOutgoing {
                targetFriendID = friend.id
            } else if let senderFriend = MessengerRepository.friend(remoteUserId: senderId, context: context) {
                targetFriendID = senderFriend.id
            } else {
                targetFriendID = friend.id
            }

            MessengerRepository.insertSyncedMessage(
                friendID: targetFriendID,
                text: sanitized,
                messageType: type,
                isOutgoing: isOutgoing,
                sentAt: timestamp,
                isRead: isRead,
                remoteDocumentId: document.documentID,
                context: context
            )
        }

        friend.hiddenFromInbox = false
        MessengerRepository.bumpInteractionOnly(for: friend.id, context: context)
        try? context.save()
        notifyInboxChanged()
    }
}
