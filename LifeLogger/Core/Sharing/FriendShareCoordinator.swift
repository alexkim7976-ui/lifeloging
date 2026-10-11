import Foundation

struct PendingIncomingShare: Equatable {
    let share: LifeLoggerShareHelper.FriendActivityShare
    let senderName: String
}

@MainActor
final class FriendShareCoordinator: ObservableObject {
    @Published var isShareSheetPresented = false
    @Published var isMessageCenterPresented = false
    @Published var receivedShare: LifeLoggerShareHelper.FriendActivityShare?
    @Published var showIncomingShareDialog = false
    @Published var pendingComposeText: String?
    @Published var pendingIncomingShare: PendingIncomingShare?
    @Published var openChatFriendID: UUID?
    @Published var statusMessage: String?
    @Published var shareSheetSnapshot: CurrentActivitySnapshot?

    func presentMessageCenter() {
        isMessageCenterPresented = true
    }

    func openMessenger(chatFriendID: UUID? = nil, composeText: String? = nil) {
        if let composeText {
            pendingComposeText = composeText
        }
        if let chatFriendID {
            openChatFriendID = chatFriendID
        }
        isMessageCenterPresented = true
    }

    func presentShareSheet(snapshot: CurrentActivitySnapshot? = nil) {
        if let snapshot {
            shareSheetSnapshot = snapshot
        }
        isShareSheetPresented = true
    }

    func handleIncomingURL(_ url: URL) {
        guard let share = LifeLoggerShareHelper.parseShareURL(url) else { return }
        receivedShare = share
        showIncomingShareDialog = true
    }

    func acceptIncomingShare(senderName: String = "친구") {
        guard let share = receivedShare else { return }
        pendingIncomingShare = PendingIncomingShare(share: share, senderName: senderName)
        pendingComposeText = BloomieMessageFormatter.buildIncomingPrefill(
            from: share,
            senderName: senderName
        )
        showIncomingShareDialog = false
        receivedShare = nil
        isMessageCenterPresented = true
    }

    func dismissIncomingShare() {
        showIncomingShareDialog = false
        receivedShare = nil
    }
}
