import SwiftUI
import SwiftData

enum MessengerRoute: Hashable {
    case chat(UUID)
}

struct MessengerRootView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var messengerContext
    @EnvironmentObject private var friendShare: FriendShareCoordinator
    @EnvironmentObject private var auth: BloomieCloudAuthService
    @EnvironmentObject private var chat: BloomieCloudChatService

    @State private var selectedTab = 0
    @State private var navigationPath: [MessengerRoute] = []
    @State private var senderName = BloomieMessageFormatter.defaultSenderName
    @State private var messengerConsent = MessengerConsentStore.hasConsented

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                BloomieMessengerBackground(theme: .data(for: .cozy))

                VStack(spacing: 0) {
                    messengerHeader

                    if !messengerConsent {
                        messengerConsentBanner
                    }

                    if auth.isSignedIn {
                        TabView(selection: $selectedTab) {
                            MessengerHomeView(
                                onOpenChat: { friendID in
                                    navigationPath.append(.chat(friendID))
                                }
                            )
                            .tag(0)

                            MessengerInboxView(
                                onOpenChat: { friendID in
                                    navigationPath.append(.chat(friendID))
                                }
                            )
                            .tag(1)
                        }
                        .tabViewStyle(.automatic)
                    } else {
                        ScrollView {
                            MessengerAccountView(auth: auth)
                                .padding(22)
                        }
                    }
                }
            }
            .navigationDestination(for: MessengerRoute.self) { route in
                switch route {
                case .chat(let friendID):
                    MessengerChatView(
                        friendID: friendID,
                        initialComposeText: friendShare.pendingComposeText
                    ) {
                        friendShare.pendingComposeText = nil
                    }
                }
            }
        }
        .frame(minWidth: 760, minHeight: 680)
        .onAppear {
            auth.configureIfNeeded()
            MessengerRepository.bootstrap(context: messengerContext)
            senderName = UserDefaults.standard.string(forKey: "lifelogger.senderName")
                ?? BloomieMessageFormatter.defaultSenderName
            processPendingNavigation()
            syncCloudFriendsIfNeeded()
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn {
                syncCloudFriendsIfNeeded()
            } else {
                chat.stopInboxSync()
            }
        }
        .onChange(of: friendShare.openChatFriendID) { _, newValue in
            guard let friendID = newValue else { return }
            navigationPath = [.chat(friendID)]
            friendShare.openChatFriendID = nil
        }
    }

    private var messengerConsentBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("bloomie 메신저를 사용하려면 클라우드 연결이 필요합니다.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            Toggle(isOn: $messengerConsent) {
                Text("클라우드 메신저 사용에 동의")
                    .foregroundStyle(.white.opacity(0.82))
            }
            .toggleStyle(.switch)
            .onChange(of: messengerConsent) { _, enabled in
                MessengerConsentStore.hasConsented = enabled
                if enabled {
                    auth.configureIfNeeded()
                    syncCloudFriendsIfNeeded()
                } else {
                    chat.stopInboxSync()
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.black.opacity(0.12))
    }

    private var messengerHeader: some View {
        HStack(spacing: 14) {
            if auth.isSignedIn {
                Picker("", selection: $selectedTab) {
                    Text("Home").tag(0)
                    Text("Chat").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            } else {
                Text("메신저")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
            }

            if auth.isSignedIn {
                HStack(spacing: 8) {
                    Text("내 이름")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    TextField("표시 이름", text: $senderName)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.16)))
                        .frame(maxWidth: 140)
                }
            }

            Spacer()

            if auth.isSignedIn, let displayId = auth.displayId {
                Menu {
                    Button("로그아웃", role: .destructive) {
                        auth.signOut()
                        chat.stopInboxSync()
                    }
                } label: {
                    Label(displayId, systemImage: "person.crop.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .menuStyle(.borderlessButton)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.black.opacity(0.08))
        .onChange(of: senderName) { _, newValue in
            let sanitized = SecureInputValidator.sanitizeAppName(newValue)
            if sanitized.isEmpty {
                UserDefaults.standard.removeObject(forKey: "lifelogger.senderName")
            } else {
                UserDefaults.standard.set(sanitized, forKey: "lifelogger.senderName")
            }
        }
    }

    private func syncCloudFriendsIfNeeded() {
        guard MessengerConsentStore.hasConsented else { return }
        auth.configureIfNeeded()
        guard auth.isSignedIn, let uid = auth.currentUID else { return }
        chat.startInboxSync(myUID: uid, context: messengerContext)
    }

    private func processPendingNavigation() {
        if let pending = friendShare.pendingIncomingShare {
            let friend = MessengerRepository.receiveActivityShare(
                from: pending.senderName,
                share: pending.share,
                context: messengerContext
            )
            friendShare.pendingIncomingShare = nil
            friendShare.pendingComposeText = BloomieMessageFormatter.buildIncomingPrefill(
                from: pending.share,
                senderName: pending.senderName
            )
            if let friend {
                navigationPath = [.chat(friend.id)]
            }
            return
        }

        if let friendID = friendShare.openChatFriendID {
            navigationPath = [.chat(friendID)]
            friendShare.openChatFriendID = nil
        }
    }
}
