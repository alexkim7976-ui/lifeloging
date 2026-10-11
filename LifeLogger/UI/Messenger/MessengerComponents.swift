import SwiftUI

struct BloomieGardenView: View {
    let interactionScore: Int
    let theme: BloomieMessengerThemeData

    private var progress: Double {
        min(Double(interactionScore) / 40.0, 1.0)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🌸 Bloomie Garden")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(theme.mode.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.22)))
            }

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.25))
                        .frame(width: 64, height: 64)
                    Text(gardenEmoji)
                        .font(.system(size: 34))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(gardenCaption)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.18))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [theme.accent, theme.blobB],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.glassTint.opacity(0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(theme.glassBorder.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private var gardenEmoji: String {
        switch interactionScore {
        case 0..<5: return "🌱"
        case 5..<15: return "🌿"
        case 15..<40: return "🌸"
        default: return "🌺"
        }
    }

    private var gardenCaption: String {
        switch interactionScore {
        case 0..<5: return "대화를 시작하면 정원이 자라요"
        case 5..<15: return "따뜻한 대화가 이어지고 있어요"
        case 15..<40: return "깊은 대화의 꽃이 피었어요"
        default: return "오래 함께한 친구의 정원"
        }
    }
}

struct MessengerFriendTile: View {
    let friend: MessengerFriend
    let theme: BloomieMessengerThemeData
    var unreadCount: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.85), theme.blobB.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text(avatarLetter)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }

                if unreadCount > 0 {
                    Text("\(min(unreadCount, 9))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(theme.accent))
                        .offset(x: 4, y: -4)
                }
            }

            Text(friend.nickname)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private var avatarLetter: String {
        if friend.isBot { return "🤖" }
        return String(friend.nickname.prefix(1))
    }
}

struct MessengerBubbleView: View {
    let message: MessengerMessage
    let theme: BloomieMessengerThemeData

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isOutgoing { Spacer(minLength: 48) }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                if message.messageType == "activity" {
                    Label("활동 공유", systemImage: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.accent.opacity(0.9))
                }

                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.isOutgoing ? Color.white : Color(red: 0.12, green: 0.14, blue: 0.22))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(bubbleFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(bubbleBorder, lineWidth: 0.8)
                            }
                    }

                Text(message.sentAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }

            if !message.isOutgoing { Spacer(minLength: 48) }
        }
    }

    private var bubbleFill: some ShapeStyle {
        if message.isOutgoing {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [theme.accent, theme.accent.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(theme.glassTint.opacity(0.92))
    }

    private var bubbleBorder: Color {
        message.isOutgoing ? .clear : theme.glassBorder.opacity(0.45)
    }
}

struct MessengerInputBar: View {
    @Binding var text: String
    let theme: BloomieMessengerThemeData
    var sendLabel: String = "전송"
    var onSend: () -> Void
    var onSendViaMessages: () -> Void
    var onSendViaBloomie: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                messengerToolButton("photo", enabled: false)
                messengerToolButton("location", enabled: false)
                messengerToolButton("calendar", enabled: false)

                TextField("메시지를 입력하세요", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(.white.opacity(0.20))
                            .overlay {
                                Capsule().stroke(.white.opacity(0.35), lineWidth: 1)
                            }
                    }

                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(theme.accent))
                }
                .buttonStyle(.plain)
                .help(sendLabel)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 10) {
                Button(action: onSendViaMessages) {
                    Label("메시지 앱", systemImage: "message.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(messengerSecondaryButtonStyle)

                Button(action: onSendViaBloomie) {
                    Label("bloomie 공유", systemImage: "heart.text.square.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(messengerBloomButtonStyle)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private func messengerToolButton(_ name: String, enabled: Bool) -> some View {
        Image(systemName: name)
            .font(.body)
            .foregroundStyle(.white.opacity(enabled ? 0.85 : 0.35))
            .frame(width: 32, height: 32)
    }

    private var messengerSecondaryButtonStyle: some ButtonStyle {
        MessengerCapsuleButtonStyle(fill: .white.opacity(0.16), foreground: .white.opacity(0.9))
    }

    private var messengerBloomButtonStyle: some ButtonStyle {
        MessengerCapsuleButtonStyle(fill: LiquidGlassStyle.bloomAccent.opacity(0.55), foreground: .white)
    }
}

private struct MessengerCapsuleButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, 8)
            .background(Capsule().fill(fill.opacity(configuration.isPressed ? 0.7 : 1)))
    }
}

struct MessengerInboxRow: View {
    let friend: MessengerFriend
    let preview: String
    let sentAt: Date?
    let unreadCount: Int
    let theme: BloomieMessengerThemeData

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.accent, theme.blobB],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay {
                    Text(friend.isBot ? "🤖" : String(friend.nickname.prefix(1)))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friend.nickname)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.94))
                    Spacer()
                    if let sentAt {
                        Text(sentAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(unreadCount > 0 ? 0.92 : 0.62))
                    .lineLimit(1)
            }

            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(theme.accent))
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(unreadCount > 0 ? 0.18 : 0.10))
        }
    }
}
