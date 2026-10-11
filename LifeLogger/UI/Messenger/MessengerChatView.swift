import SwiftUI
import SwiftData

struct MessengerChatView: View {
    @Environment(\.modelContext) private var messengerContext
    @EnvironmentObject private var tracker: ActivityTracker
    @EnvironmentObject private var auth: BloomieCloudAuthService
    @EnvironmentObject private var chat: BloomieCloudChatService

    let friendID: UUID
    var initialComposeText: String?
    var onConsumeInitialText: () -> Void = {}

    @State private var friend: MessengerFriend?
    @State private var messages: [MessengerMessage] = []
    @State private var composeText = ""
    @State private var deliveryMessage: String?
    @State private var showDeliveryAlert = false

    private var theme: BloomieMessengerThemeData {
        .data(for: MessengerRepository.themeMode(for: friendID, context: messengerContext))
    }

    private var canUseCloudChat: Bool {
        auth.isSignedIn && friend?.remoteUserId != nil
    }

    var body: some View {
        ZStack {
            BloomieMessengerBackground(theme: theme)

            if let friend {
                VStack(spacing: 0) {
                    chatHeader(friend)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages, id: \.id) { message in
                                    MessengerBubbleView(message: message, theme: theme)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onAppear {
                            scrollToBottom(proxy: proxy)
                        }
                    }

                    MessengerInputBar(
                        text: $composeText,
                        theme: theme,
                        sendLabel: canUseCloudChat ? "전송" : "저장",
                        onSend: sendPrimary,
                        onSendViaMessages: { send(channel: .messages) },
                        onSendViaBloomie: { Task { await sendViaInAppBloomie() } }
                    )
                    .padding(16)
                }
            } else {
                ProgressView("대화 불러오는 중…")
                    .foregroundStyle(.white)
            }
        }
        .navigationBarBackButtonHidden(false)
        .onAppear {
            reload()
            if let uid = auth.currentUID, let friend {
                Task {
                    await chat.markReadInCloud(friend: friend, myUID: uid, context: messengerContext)
                    MessengerRepository.markRead(friendID: friendID, context: messengerContext)
                    reload()
                }
            } else {
                MessengerRepository.markRead(friendID: friendID, context: messengerContext)
            }
            if composeText.isEmpty, let initialComposeText {
                composeText = initialComposeText
                onConsumeInitialText()
            }
        }
        .onChange(of: chat.inboxRevision) { _, _ in reload() }
        .alert("전송", isPresented: $showDeliveryAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(deliveryMessage ?? "")
        }
    }

    private func chatHeader(_ friend: MessengerFriend) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.accent, theme.blobB],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay {
                    Text(friend.isBot ? "🤖" : String(friend.nickname.prefix(1)))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.nickname)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.94))
                Text(canUseCloudChat ? "실시간 연결됨 · \(theme.mode.label)" : "로컬 저장 · \(theme.mode.label)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.black.opacity(0.10))
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func reload() {
        friend = MessengerRepository.friend(id: friendID, context: messengerContext)
        messages = MessengerRepository.messages(for: friendID, context: messengerContext)
    }

    private func sendPrimary() {
        guard let friend else { return }

        if canUseCloudChat, let uid = auth.currentUID {
            Task {
                do {
                    try await chat.sendText(
                        composeText,
                        to: friend,
                        myUID: uid,
                        context: messengerContext
                    )
                    composeText = ""
                    reload()
                } catch {
                    deliveryMessage = error.localizedDescription
                    showDeliveryAlert = true
                }
            }
            return
        }

        send(channel: .localOnly)
    }

    private func sendViaInAppBloomie() async {
        guard let friend else { return }

        let snapshot = CurrentActivityShareService.snapshot(
            from: tracker,
            focusRatioToday: tracker.todayFocusRatio
        )

        let result = await BloomieInAppMessengerService.deliver(
            message: composeText,
            snapshot: snapshot,
            to: friend,
            context: messengerContext
        )

        deliveryMessage = message(for: result, friend: friend)
        showDeliveryAlert = true

        switch result {
        case .failed:
            return
        default:
            composeText = ""
            reload()
        }
    }

    private func send(channel: MessageDeliveryService.DeliveryChannel) {
        guard let friend else { return }

        let snapshot = CurrentActivityShareService.snapshot(
            from: tracker,
            focusRatioToday: tracker.todayFocusRatio
        )

        let result = MessageDeliveryService.deliverToFriend(
            friend: friend,
            message: composeText,
            snapshot: snapshot,
            channel: channel,
            messengerContext: messengerContext
        )

        deliveryMessage = message(for: result, friend: friend)
        showDeliveryAlert = true

        switch result {
        case .failed:
            return
        default:
            composeText = ""
            reload()
        }
    }

    private func message(for result: MessageDeliveryService.DeliveryResult, friend: MessengerFriend) -> String {
        switch result {
        case .sentMessages:
            return "\(friend.nickname)에게 메시지 앱으로 보냈습니다."
        case .sentBloomie(let text):
            return text
        case .sentSocialApp(let text):
            return text
        case .savedLocally:
            return "메시지를 저장했습니다."
        case .failed(let reason):
            return reason
        }
    }
}
