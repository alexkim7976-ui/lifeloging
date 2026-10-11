import SwiftUI

struct FriendShareSheetView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.dismiss) private var dismiss

    let snapshot: CurrentActivitySnapshot
    var onResult: (String) -> Void = { _ in }

    @State private var composeText = ""
    @State private var senderName = ""
    @State private var isKakaoTalkInstalled = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    activityPreview
                    composeSection
                    quickSendSection
                    socialAppsSection

                    if snapshot.canShare {
                        externalShareSection
                    }

                    privacyNote
                }
                .padding(28)
            }
        }
        .frame(width: 480, height: 580)
        .onAppear {
            loadSheetContent()
        }
        .onChange(of: senderName) { _, newValue in
            let sanitized = SecureInputValidator.sanitizeAppName(newValue)
            if sanitized.isEmpty {
                UserDefaults.standard.removeObject(forKey: "lifelogger.senderName")
            } else {
                UserDefaults.standard.set(sanitized, forKey: "lifelogger.senderName")
            }
            composeText = BloomieMessageFormatter.buildOutgoingPrefill(from: snapshot, senderName: senderName)
        }
        .id(languageStore.language.rawValue)
    }

    private var header: some View {
        HStack {
            LiquidGlassSectionHeader(title: L10n.tr("share.title"), systemImage: "paperplane.fill")
            Spacer()
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

    private var activityPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("share.currentActivity"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            HStack(spacing: 12) {
                AppIconView(
                    appName: snapshot.appName,
                    bundleIdentifier: snapshot.bundleIdentifier,
                    size: 44,
                    cornerRadius: 12
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.headline)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LiquidGlassStyle.titleText)
                    Text(snapshot.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                        .lineLimit(2)
                    if let goal = snapshot.goalLabel {
                        Text("🎯 \(goal)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LiquidGlassStyle.iceBlue)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(18)
        .liquidGlassCard()
    }

    private var composeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("share.message"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            HStack(spacing: 10) {
                Text(L10n.tr("share.sender"))
                    .font(.caption)
                    .foregroundStyle(LiquidGlassStyle.tertiaryText)
                TextField("내 이름", text: $senderName)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .liquidGlassInsetPanel(cornerRadius: 8)
            }

            TextEditor(text: $composeText)
                .font(.body)
                .frame(height: 96)
                .scrollContentBackground(.hidden)
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 12)

            Text("메시지 앱, 카카오톡, Instagram 등으로 바로 보낼 수 있습니다.")
                .font(.caption2)
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
        }
    }

    private var quickSendSection: some View {
        VStack(spacing: 10) {
            Button {
                deliverViaExternalChannel(.messages)
            } label: {
                Label(L10n.tr("share.messages"), systemImage: "message.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassPrimaryButtonStyle())
            .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                if CurrentActivityShareService.copyToClipboard(snapshot) {
                    onResult("메시지를 클립보드에 복사했습니다.")
                } else {
                    onResult("복사할 내용이 없습니다.")
                }
            } label: {
                Label(L10n.tr("share.copy"), systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassSecondaryButtonStyle())
            .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var socialAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("share.sns"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            Button {
                deliverViaExternalChannel(.instagram)
            } label: {
                Label(L10n.tr("share.instagram"), systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassInstagramButtonStyle())
            .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if isKakaoTalkInstalled {
                Button {
                    deliverViaExternalChannel(.kakaoTalk)
                } label: {
                    Label(L10n.tr("share.kakao"), systemImage: "bubble.left.and.bubble.right.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiquidGlassKakaoButtonStyle())
                .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text(isKakaoTalkInstalled
                ? L10n.tr("share.kakaoHint")
                : L10n.tr("share.instagramHint"))
                .font(.caption2)
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
        }
    }

    private var externalShareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("share.external"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            if let webURL = ActivityWebShareService.buildWebShareURL(from: snapshot, senderName: senderName) {
                Text(webURL.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(LiquidGlassStyle.iceBlue)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .padding(10)
                    .liquidGlassInsetPanel(cornerRadius: 10)
            }

            Button {
                copyWebShareLink()
            } label: {
                Label(L10n.tr("share.webLink"), systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassPrimaryButtonStyle())

            AirDropShareButton(snapshot: snapshot, senderName: senderName) {
                Label(L10n.tr("share.airdrop"), systemImage: "airdrop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassSecondaryButtonStyle())

            MacShareButton(snapshot: snapshot, senderName: senderName) {
                Label(L10n.tr("share.otherApps"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassSecondaryButtonStyle())

            Text("AirDrop·공유 시트에는 메시지와 웹 링크가 함께 포함됩니다.")
                .font(.caption2)
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
        }
    }

    private var privacyNote: some View {
        Text(L10n.tr("share.privacy"))
            .font(.caption2)
            .foregroundStyle(LiquidGlassStyle.tertiaryText)
            .multilineTextAlignment(.center)
    }

    private func copyWebShareLink() {
        if let url = ActivityWebShareService.copyWebShareLink(from: snapshot, senderName: senderName) {
            onResult("웹 링크를 복사했습니다.\n\n\(url)")
        } else {
            onResult("지금 공유할 활동이 없습니다.")
        }
    }

    private func deliverViaExternalChannel(_ channel: MessageDeliveryService.DeliveryChannel) {
        let result = MessageDeliveryService.deliverViaSocialChannel(
            message: composeText,
            snapshot: snapshot,
            channel: channel,
            senderName: senderName
        )
        handleExternalResult(result)
    }

    private func loadSheetContent() {
        senderName = UserDefaults.standard.string(forKey: "lifelogger.senderName")
            ?? BloomieMessageFormatter.defaultSenderName
        composeText = BloomieMessageFormatter.buildOutgoingPrefill(from: snapshot, senderName: senderName)
        isKakaoTalkInstalled = SocialAppShareService.isInstalled(.kakaoTalk)
    }

    private func handleExternalResult(_ result: MessageDeliveryService.DeliveryResult) {
        switch result {
        case .sentMessages:
            onResult("메시지 앱으로 보냈습니다.")
        case .sentSocialApp(let text):
            onResult(text)
        case .failed(let reason):
            onResult(reason)
        default:
            break
        }
    }
}

struct IncomingShareDialogView: View {
    let share: LifeLoggerShareHelper.FriendActivityShare
    let senderName: String
    var onRecord: () -> Void
    var onDismiss: () -> Void

    private var statusLine: String {
        let verb = "\(share.category.bloomieCategoryLabel) 중"
        if share.windowTitle.isEmpty {
            return "지금 \(share.appName) \(verb)"
        }
        return "지금 \(share.appName) \(verb) — \(share.windowTitle)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LiquidGlassSectionHeader(title: "\(senderName) 님의 현재 활동", systemImage: "link")

            Text(statusLine)
                .font(.body.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.bodyText)

            Text("외부에서 받은 정보예요. 보낸 사람은 검증되지 않았습니다.")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.statusPaused)
                .padding(10)
                .liquidGlassInsetPanel(cornerRadius: 10)

            Text("'메시지에 기록'을 누르면 bloomie 메신저 입력창에 채워져요.")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            HStack(spacing: 10) {
                Button("닫기", action: onDismiss)
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
                Button("메시지에 기록", action: onRecord)
                    .buttonStyle(LiquidGlassPrimaryButtonStyle())
            }
        }
        .padding(24)
        .liquidGlassCard(strong: true)
        .frame(width: 420)
    }
}

struct FriendReceivedShareView: View {
    let share: LifeLoggerShareHelper.FriendActivityShare
    var onDismiss: () -> Void

    private var elapsedLabel: String {
        let minutes = share.elapsedSeconds / 60
        let seconds = share.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LiquidGlassSectionHeader(title: "친구의 현재 활동", systemImage: "person.wave.2.fill")
                Spacer()
                Button("닫기", action: onDismiss)
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
            }

            HStack(spacing: 12) {
                Image(systemName: share.category.systemImage)
                    .font(.title2)
                    .foregroundStyle(LiquidGlassStyle.iceBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(share.appName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LiquidGlassStyle.titleText)
                    Text(share.windowTitle.isEmpty ? share.category.localizedName : share.windowTitle)
                        .font(.subheadline)
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 10) {
                Text("집중 \(share.focusPercent)%")
                Text("·")
                Text(elapsedLabel)
                Text("·")
                Text(share.category.localizedName)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(LiquidGlassStyle.secondaryText)
        }
        .padding(20)
        .liquidGlassCard(strong: true)
    }
}
