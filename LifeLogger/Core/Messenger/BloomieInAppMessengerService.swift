import Foundation
import SwiftData

/// bloomie 앱 없이 LifeLogger 내장 메신저(Firestore)로 bloomie 호환 전송
@MainActor
enum BloomieInAppMessengerService {
    static func loadLocalFriends(context: ModelContext) -> [MessengerFriend] {
        MessengerRepository.friends(context: context)
    }

    static func deliver(
        message: String,
        snapshot: CurrentActivitySnapshot?,
        to friend: MessengerFriend,
        context: ModelContext
    ) async -> MessageDeliveryService.DeliveryResult {
        BloomieCloudAuthService.shared.configureIfNeeded()

        guard BloomieCloudAuthService.shared.isSignedIn,
              let uid = BloomieCloudAuthService.shared.currentUID else {
            return .failed("bloomie 메신저를 사용하려면 bloomie 계정으로 로그인해주세요.")
        }

        guard friend.remoteUserId != nil else {
            return .failed("bloomie 아이디로 등록된 친구에게만 보낼 수 있습니다.")
        }

        let trimmed = SecureInputValidator.sanitizeText(message, maxLength: 500)
        guard !trimmed.isEmpty else {
            return .failed("보낼 메시지를 입력해주세요.")
        }

        do {
            if let snapshot {
                try await BloomieCloudChatService.shared.sendActivityShare(
                    message: trimmed,
                    snapshot: snapshot,
                    to: friend,
                    myUID: uid,
                    context: context
                )
            } else {
                try await BloomieCloudChatService.shared.sendText(
                    trimmed,
                    to: friend,
                    myUID: uid,
                    context: context
                )
            }

            return .sentBloomie(
                "\(friend.nickname)에게 bloomie 메신저로 보냈습니다. bloomie 앱을 쓰는 친구도 같은 채팅에서 받을 수 있어요."
            )
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func ensureReady(context: ModelContext) {
        if !MessengerConsentStore.hasConsented {
            MessengerConsentStore.hasConsented = true
        }
    }
    static func syncFriendsFromCloud(context: ModelContext, startInbox: Bool = false) async {
        await Task.yield()
        BloomieCloudAuthService.shared.configureIfNeeded()
        guard BloomieCloudAuthService.shared.isSignedIn,
              let uid = BloomieCloudAuthService.shared.currentUID else { return }
        await BloomieCloudChatService.shared.syncFriends(uid: uid, context: context)
        if startInbox {
            BloomieCloudChatService.shared.startInboxSync(myUID: uid, context: context)
        }
    }

    static func syncFriends(context: ModelContext) async {
        await syncFriendsFromCloud(context: context, startInbox: true)
    }
}
