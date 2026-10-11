import AppKit
import Foundation
import SwiftData

enum MessageDeliveryService {
    enum DeliveryResult: Sendable {
        case sentMessages
        case sentBloomie(String)
        case sentSocialApp(String)
        case savedLocally
        case failed(String)
    }

    @MainActor
    static func deliverToFriend(
        friend: MessengerFriend,
        message: String,
        snapshot: CurrentActivitySnapshot?,
        channel: DeliveryChannel,
        messengerContext: ModelContext
    ) -> DeliveryResult {
        let trimmed = SecureInputValidator.sanitizeText(message, maxLength: 500)
        guard !trimmed.isEmpty else {
            return .failed("보낼 메시지를 입력해주세요.")
        }

        let body: String
        if let snapshot {
            body = BloomieMessageFormatter.buildDeliveryBody(message: trimmed, snapshot: snapshot)
        } else {
            body = trimmed
        }

        switch channel {
        case .messages:
            guard openMessages(with: body) else {
                return .failed("메시지 앱을 열 수 없습니다.")
            }
            MessengerRepository.sendMessage(to: friend, text: trimmed, context: messengerContext)
            return .sentMessages

        case .bloomie:
            guard snapshot != nil else {
                return .failed("현재 활동이 없어 bloomie 메신저로 보낼 수 없습니다.")
            }
            return .failed("bloomie 메신저 전송은 앱 내 공유 화면에서 이용해주세요.")

        case .localOnly:
            MessengerRepository.sendMessage(to: friend, text: trimmed, context: messengerContext)
            return .savedLocally

        case .kakaoTalk:
            return deliverViaSocialApp(
                body: socialShareBody(message: trimmed, snapshot: snapshot),
                app: .kakaoTalk,
                friendName: friend.nickname
            ) {
                MessengerRepository.sendMessage(to: friend, text: trimmed, context: messengerContext)
            }

        case .instagram:
            return deliverViaSocialApp(
                body: socialShareBody(message: trimmed, snapshot: snapshot),
                app: .instagram,
                friendName: friend.nickname
            ) {
                MessengerRepository.sendMessage(to: friend, text: trimmed, context: messengerContext)
            }
        }
    }

    @MainActor
    static func deliverToFriend(
        friend: FriendContact,
        message: String,
        snapshot: CurrentActivitySnapshot?,
        channel: DeliveryChannel
    ) -> DeliveryResult {
        let trimmed = SecureInputValidator.sanitizeText(message, maxLength: 500)
        guard !trimmed.isEmpty else {
            return .failed("보낼 메시지를 입력해주세요.")
        }

        let body: String
        if let snapshot {
            body = BloomieMessageFormatter.buildDeliveryBody(message: trimmed, snapshot: snapshot)
        } else {
            body = trimmed
        }

        switch channel {
        case .messages:
            guard openMessages(with: body) else {
                return .failed("메시지 앱을 열 수 없습니다.")
            }
            FriendMessageStore.shared.appendMessage(to: friend, text: trimmed)
            return .sentMessages

        case .bloomie:
            guard snapshot != nil else {
                return .failed("현재 활동이 없어 bloomie 메신저로 보낼 수 없습니다.")
            }
            return .failed("bloomie 메신저 전송은 앱 내 공유 화면에서 이용해주세요.")

        case .localOnly:
            FriendMessageStore.shared.appendMessage(to: friend, text: trimmed)
            return .savedLocally

        case .kakaoTalk:
            return deliverViaSocialApp(
                body: socialShareBody(message: trimmed, snapshot: snapshot),
                app: .kakaoTalk,
                friendName: friend.nickname
            ) {
                FriendMessageStore.shared.appendMessage(to: friend, text: trimmed)
            }

        case .instagram:
            return deliverViaSocialApp(
                body: socialShareBody(message: trimmed, snapshot: snapshot),
                app: .instagram,
                friendName: friend.nickname
            ) {
                FriendMessageStore.shared.appendMessage(to: friend, text: trimmed)
            }
        }
    }

    @MainActor
    static func deliverViaSocialChannel(
        message: String,
        snapshot: CurrentActivitySnapshot?,
        channel: DeliveryChannel,
        senderName: String?
    ) -> DeliveryResult {
        let trimmed = SecureInputValidator.sanitizeText(message, maxLength: 500)
        guard !trimmed.isEmpty else {
            return .failed("보낼 메시지를 입력해주세요.")
        }

        switch channel {
        case .instagram, .kakaoTalk:
            let app: SocialAppShareService.SocialApp = channel == .instagram ? .instagram : .kakaoTalk
            let body = socialShareBody(message: trimmed, snapshot: snapshot, senderName: senderName)
            switch SocialAppShareService.share(text: body, via: app) {
            case .opened:
                return .sentSocialApp(SocialAppShareService.successMessage(for: app, friendName: nil))
            case .failed(let reason):
                return .failed(reason)
            }
        case .messages:
            let body = snapshot.map {
                ActivityWebShareService.buildShareText(
                    message: trimmed,
                    snapshot: $0,
                    senderName: senderName
                )
            } ?? trimmed
            guard openMessages(with: body) else {
                return .failed("메시지 앱을 열 수 없습니다.")
            }
            return .sentMessages
        default:
            return .failed("지원하지 않는 공유 방식입니다.")
        }
    }

    private static func socialShareBody(
        message: String,
        snapshot: CurrentActivitySnapshot?,
        senderName: String? = nil
    ) -> String {
        guard let snapshot else { return message }
        return ActivityWebShareService.buildShareText(
            message: message,
            snapshot: snapshot,
            senderName: senderName
        )
    }

    @MainActor
    private static func deliverViaSocialApp(
        body: String,
        app: SocialAppShareService.SocialApp,
        friendName: String,
        saveLocally: () -> Void
    ) -> DeliveryResult {
        switch SocialAppShareService.share(text: body, via: app) {
        case .opened:
            saveLocally()
            return .sentSocialApp(SocialAppShareService.successMessage(for: app, friendName: friendName))
        case .failed(let reason):
            return .failed(reason)
        }
    }

    @MainActor
    static func openMessages(with text: String) -> Bool {
        if let service = NSSharingService(named: .composeMessage) {
            service.perform(withItems: [text])
            return true
        }

        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        guard let url = URL(string: "sms:&body=\(encoded)") else { return false }
        return NSWorkspace.shared.open(url)
    }

    enum DeliveryChannel: Sendable {
        case messages
        case bloomie
        case kakaoTalk
        case instagram
        case localOnly
    }
}
