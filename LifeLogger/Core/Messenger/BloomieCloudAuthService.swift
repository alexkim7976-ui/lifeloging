import FirebaseAuth
import FirebaseCore
import Foundation

enum BloomieCloudAuthError: LocalizedError {
    case notConfigured
    case emptyFields
    case invalidDisplayId
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "bloomie 클라우드 연결을 초기화하지 못했습니다."
        case .emptyFields:
            return "모든 항목을 입력해주세요."
        case .invalidDisplayId:
            return "아이디는 영문, 숫자, 밑줄만 사용할 수 있습니다."
        case .underlying(let message):
            return message
        }
    }
}

@MainActor
final class BloomieCloudAuthService: ObservableObject {
    static let shared = BloomieCloudAuthService()

    @Published private(set) var currentUID: String?
    @Published private(set) var displayId: String?
    @Published private(set) var displayName: String?
    @Published private(set) var isConfigured = false
    @Published var lastError: String?

    var isSignedIn: Bool { currentUID != nil }

    private var authListener: AuthStateDidChangeListenerHandle?

    private init() {}

    func configureIfNeeded() {
        guard MessengerConsentStore.hasConsented else {
            AppLogger.privacy.info("Skipping Firebase configure — messenger not consented")
            return
        }
        guard !isConfigured else { return }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        FirebaseAuthKeychainSupport.configureAccessGroupIfNeeded()

        isConfigured = true
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.applyUser(user)
            }
        }
        applyUser(Auth.auth().currentUser)
    }

    func signIn(displayId rawDisplayId: String, password: String) async throws {
        configureIfNeeded()
        let displayId = try sanitizeDisplayId(rawDisplayId)
        guard !password.isEmpty else { throw BloomieCloudAuthError.emptyFields }

        do {
            let result = try await Auth.auth().signIn(withEmail: bloomieEmail(for: displayId), password: password)
            applyUser(result.user)
            await loadProfile(for: result.user.uid)
        } catch {
            throw BloomieCloudAuthError.underlying(mapAuthError(error))
        }
    }

    func signUp(displayId rawDisplayId: String, password: String, nickname: String) async throws {
        configureIfNeeded()
        let displayId = try sanitizeDisplayId(rawDisplayId)
        let name = SecureInputValidator.sanitizeAppName(nickname)
        guard !password.isEmpty, !name.isEmpty else { throw BloomieCloudAuthError.emptyFields }

        do {
            let result = try await Auth.auth().createUser(
                withEmail: bloomieEmail(for: displayId),
                password: password
            )
            try await BloomieCloudChatService.shared.createUserDocument(
                uid: result.user.uid,
                displayId: displayId,
                nickname: name
            )
            applyUser(result.user)
            displayName = name
            self.displayId = displayId
        } catch {
            throw BloomieCloudAuthError.underlying(mapAuthError(error))
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        applyUser(nil)
    }

    private func applyUser(_ user: User?) {
        currentUID = user?.uid
        if user == nil {
            displayId = nil
            displayName = nil
        }
    }

    private func loadProfile(for uid: String) async {
        guard let profile = await BloomieCloudChatService.shared.fetchUserProfile(uid: uid) else { return }
        displayId = profile.displayId
        displayName = profile.name
    }

    private func bloomieEmail(for displayId: String) -> String {
        "\(displayId.lowercased())@bloomie.local"
    }

    private func sanitizeDisplayId(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { throw BloomieCloudAuthError.emptyFields }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw BloomieCloudAuthError.invalidDisplayId
        }
        return trimmed
    }

    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .wrongPassword, .invalidCredential, .userNotFound:
            return "아이디 또는 비밀번호가 올바르지 않습니다."
        case .emailAlreadyInUse:
            return "이미 사용 중인 아이디입니다."
        case .weakPassword:
            return "비밀번호가 너무 약합니다."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        case .keychainError:
            return "키체인 접근에 실패했습니다. 앱을 완전히 종료한 뒤 다시 실행하거나, Xcode에서 Clean Build 후 재설치해주세요."
        default:
            if error.localizedDescription.localizedCaseInsensitiveContains("keychain") {
                return "키체인 접근에 실패했습니다. 앱을 완전히 종료한 뒤 다시 실행해주세요."
            }
            return error.localizedDescription
        }
    }
}
