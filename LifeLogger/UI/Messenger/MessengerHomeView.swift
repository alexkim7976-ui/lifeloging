import SwiftUI
import SwiftData

struct MessengerHomeView: View {
    @Environment(\.modelContext) private var messengerContext
    @EnvironmentObject private var auth: BloomieCloudAuthService
    @EnvironmentObject private var chat: BloomieCloudChatService

    var onOpenChat: (UUID) -> Void

    @State private var friends: [MessengerFriend] = []
    @State private var newFriendName = ""
    @State private var newFriendID = ""
    @State private var showAddFriend = false
    @State private var addFriendError: String?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                BloomieGardenView(
                    interactionScore: totalInteractionScore,
                    theme: .data(for: .cozy)
                )

                HStack {
                    Text("친구")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                    Button {
                        showAddFriend.toggle()
                    } label: {
                        Label("추가", systemImage: "person.badge.plus")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BloomieMessengerThemeData.data(for: .cozy).accent)
                }

                if showAddFriend {
                    addFriendPanel
                }

                if friends.isEmpty {
                    Text("bloomie 아이디로 친구를 추가하면 실시간으로 문자를 주고받을 수 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(friends, id: \.id) { friend in
                        Button {
                            onOpenChat(friend.id)
                        } label: {
                            MessengerFriendTile(
                                friend: friend,
                                theme: theme(for: friend),
                                unreadCount: unreadCount(for: friend)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(22)
        }
        .onAppear(perform: reload)
        .onChange(of: chat.syncingFriends) { _, _ in reload() }
        .onChange(of: chat.inboxRevision) { _, _ in reload() }
    }

    private var addFriendPanel: some View {
        VStack(spacing: 10) {
            TextField("bloomie 아이디", text: $newFriendID)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.16)))

            TextField("표시 이름(별칭)", text: $newFriendName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.16)))

            if let addFriendError {
                Text(addFriendError)
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("친구 추가") {
                Task { await addFriend() }
            }
            .buttonStyle(.borderedProminent)
            .tint(BloomieMessengerThemeData.data(for: .cozy).accent)
            .disabled(
                newFriendName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || newFriendID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.12)))
    }

    private func addFriend() async {
        addFriendError = nil

        guard auth.isSignedIn, let uid = auth.currentUID else {
            addFriendError = "먼저 bloomie 계정으로 로그인해주세요."
            return
        }

        do {
            let friend = try await chat.addFriendByDisplayId(
                newFriendID,
                alias: newFriendName,
                myUID: uid,
                myDisplayName: auth.displayName,
                context: messengerContext
            )
            newFriendName = ""
            newFriendID = ""
            showAddFriend = false
            reload()
            onOpenChat(friend.id)
        } catch {
            addFriendError = error.localizedDescription
        }
    }

    private var totalInteractionScore: Int {
        friends.reduce(0) { partial, friend in
            partial + MessengerRepository.interactionScore(for: friend.id, context: messengerContext)
        }
    }

    private func theme(for friend: MessengerFriend) -> BloomieMessengerThemeData {
        .data(for: MessengerRepository.themeMode(for: friend.id, context: messengerContext))
    }

    private func unreadCount(for friend: MessengerFriend) -> Int {
        MessengerRepository.messages(for: friend.id, context: messengerContext)
            .filter { !$0.isOutgoing && !$0.isRead }
            .count
    }

    private func reload() {
        friends = MessengerRepository.friends(context: messengerContext)
    }
}
