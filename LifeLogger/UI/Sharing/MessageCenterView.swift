import SwiftUI

struct MessageCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = FriendMessageStore.shared
    @EnvironmentObject private var friendShare: FriendShareCoordinator

    @State private var selectedFriend: FriendContact?
    @State private var newFriendName = ""
    @State private var senderName = ""

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 18) {
                header
                senderNameField

                if let selectedFriend {
                    FriendChatView(
                        friend: selectedFriend,
                        initialComposeText: friendShare.pendingComposeText
                    ) {
                        friendShare.pendingComposeText = nil
                    }
                } else {
                    friendList
                }
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 560)
        .onAppear {
            store.reload()
            senderName = store.senderDisplayName ?? BloomieMessageFormatter.defaultSenderName
            if selectedFriend == nil, let first = store.friends.first {
                selectedFriend = first
            }
        }
        .onChange(of: senderName) { _, newValue in
            store.senderDisplayName = newValue
        }
    }

    private var header: some View {
        HStack {
            LiquidGlassSectionHeader(title: "메시지", systemImage: "bubble.left.and.bubble.right.fill")
            Spacer()
            if selectedFriend != nil {
                Button("친구 목록") {
                    selectedFriend = nil
                }
                .buttonStyle(LiquidGlassSecondaryButtonStyle())
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private var senderNameField: some View {
        HStack(spacing: 10) {
            Text("내 이름")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)
            TextField("친구에게 보일 이름", text: $senderName)
                .textFieldStyle(.plain)
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 10)
        }
    }

    private var friendList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField("친구 이름 추가", text: $newFriendName)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .liquidGlassInsetPanel(cornerRadius: 10)
                Button("추가") {
                    if let friend = store.addFriend(nickname: newFriendName) {
                        selectedFriend = friend
                        newFriendName = ""
                    }
                }
                .buttonStyle(LiquidGlassPrimaryButtonStyle())
            }

            if store.friends.isEmpty {
                Text("친구를 추가하면 bloomie처럼 메시지를 주고받을 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.friends) { friend in
                            Button {
                                selectedFriend = friend
                            } label: {
                                friendRow(friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(18)
        .liquidGlassCard()
    }

    private func friendRow(_ friend: FriendContact) -> some View {
        HStack {
            Circle()
                .fill(LiquidGlassStyle.lavenderMist.opacity(0.8))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(friend.nickname.prefix(1)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.nickname)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                if let latest = store.latestMessage(for: friend) {
                    Text(latest.text)
                        .font(.caption)
                        .foregroundStyle(LiquidGlassStyle.secondaryText)
                        .lineLimit(1)
                } else {
                    Text("아직 메시지 없음")
                        .font(.caption)
                        .foregroundStyle(LiquidGlassStyle.tertiaryText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
        }
        .padding(12)
        .liquidGlassInsetPanel(cornerRadius: 14)
    }
}

struct FriendChatView: View {
    let friend: FriendContact
    var initialComposeText: String?
    var onConsumeInitialText: () -> Void = {}

    @ObservedObject private var store = FriendMessageStore.shared

    @State private var composeText = ""
    @State private var deliveryMessage: String?
    @State private var showDeliveryAlert = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(friend.nickname)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(LiquidGlassStyle.titleText)
                Spacer()
                Button(role: .destructive) {
                    store.removeFriend(friend)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(LiquidGlassStyle.statusAfk)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.messages(for: friend)) { message in
                        messageBubble(message)
                    }
                }
            }
            .frame(maxHeight: 220)

            TextEditor(text: $composeText)
                .font(.body)
                .frame(height: 90)
                .scrollContentBackground(.hidden)
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 12)

            HStack(spacing: 10) {
                Button {
                    send(channel: .messages)
                } label: {
                    Label("메시지", systemImage: "message.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiquidGlassPrimaryButtonStyle())

                Button {
                    send(channel: .bloomie)
                } label: {
                    Label("bloomie", systemImage: "heart.text.square.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiquidGlassBloomButtonStyle())
            }
        }
        .padding(18)
        .liquidGlassCard(strong: true)
        .onAppear {
            if composeText.isEmpty, let initialComposeText {
                composeText = initialComposeText
                onConsumeInitialText()
            }
        }
        .alert("전송", isPresented: $showDeliveryAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(deliveryMessage ?? "")
        }
    }

    private func messageBubble(_ message: StoredMessage) -> some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 40) }
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(LiquidGlassStyle.bodyText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(message.isOutgoing ? LiquidGlassStyle.azure.opacity(0.55) : Color.white.opacity(0.14))
                }
            if !message.isOutgoing { Spacer(minLength: 40) }
        }
    }

    private func send(channel: MessageDeliveryService.DeliveryChannel) {
        let result = MessageDeliveryService.deliverToFriend(
            friend: friend,
            message: composeText,
            snapshot: nil,
            channel: channel
        )
        deliveryMessage = message(for: result)
        showDeliveryAlert = true
        if case .failed = result { return }
        composeText = ""
    }

    private func message(for result: MessageDeliveryService.DeliveryResult) -> String {
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
