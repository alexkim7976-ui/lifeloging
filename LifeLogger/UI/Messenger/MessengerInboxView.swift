import SwiftUI
import SwiftData

struct MessengerInboxView: View {
    @Environment(\.modelContext) private var messengerContext
    @EnvironmentObject private var chat: BloomieCloudChatService

    var onOpenChat: (UUID) -> Void

    @State private var friends: [MessengerFriend] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if friends.isEmpty {
                    emptyState
                } else {
                    ForEach(sortedFriends, id: \.id) { friend in
                        Button {
                            onOpenChat(friend.id)
                        } label: {
                            MessengerInboxRow(
                                friend: friend,
                                preview: preview(for: friend),
                                sentAt: MessengerRepository.latestMessage(for: friend.id, context: messengerContext)?.sentAt,
                                unreadCount: unreadCount(for: friend),
                                theme: theme(for: friend)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("대화 숨기기") {
                                MessengerRepository.hideChat(friend, context: messengerContext)
                                reload()
                            }
                            if !friend.isBot {
                                Button("친구 삭제", role: .destructive) {
                                    MessengerRepository.removeFriend(friend, context: messengerContext)
                                    reload()
                                }
                            }
                        }
                    }
                }
            }
            .padding(22)
        }
        .onAppear(perform: reload)
        .onChange(of: chat.inboxRevision) { _, _ in reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("아직 대화가 없어요")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
            Text("Home 탭에서 친구를 추가하거나 LifeLogger Bot과 대화를 시작해보세요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
    }

    private var sortedFriends: [MessengerFriend] {
        friends.sorted { lhs, rhs in
            let lhsDate = MessengerRepository.latestMessage(for: lhs.id, context: messengerContext)?.sentAt ?? lhs.createdAt
            let rhsDate = MessengerRepository.latestMessage(for: rhs.id, context: messengerContext)?.sentAt ?? rhs.createdAt
            return lhsDate > rhsDate
        }
    }

    private func preview(for friend: MessengerFriend) -> String {
        MessengerRepository.latestMessage(for: friend.id, context: messengerContext)?.text ?? "대화를 시작해보세요"
    }

    private func unreadCount(for friend: MessengerFriend) -> Int {
        MessengerRepository.messages(for: friend.id, context: messengerContext)
            .filter { !$0.isOutgoing && !$0.isRead }
            .count
    }

    private func theme(for friend: MessengerFriend) -> BloomieMessengerThemeData {
        .data(for: MessengerRepository.themeMode(for: friend.id, context: messengerContext))
    }

    private func reload() {
        friends = MessengerRepository.friends(context: messengerContext)
    }
}
