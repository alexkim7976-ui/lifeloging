import SwiftUI

struct MessengerAccountView: View {
    @ObservedObject var auth: BloomieCloudAuthService

    @State private var mode: AccountMode = .signIn
    @State private var displayId = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private enum AccountMode: String, CaseIterable, Identifiable {
        case signIn
        case signUp

        var id: String { rawValue }

        var title: String {
            switch self {
            case .signIn: return "로그인"
            case .signUp: return "회원가입"
            }
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("bloomie 클라우드")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.94))
                Text("bloomie와 같은 계정으로 친구와 실시간 문자를 주고받을 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }

            Picker("", selection: $mode) {
                ForEach(AccountMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 10) {
                accountField("아이디", text: $displayId)
                SecureField("비밀번호", text: $password)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(fieldBackground)

                if mode == .signUp {
                    accountField("닉네임", text: $nickname)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await submit() }
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text(mode == .signIn ? "로그인" : "가입하고 시작")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(BloomieMessengerThemeData.data(for: .cozy).accent)
            .disabled(isLoading)

            Text("기존 bloomie 아이디·비밀번호를 그대로 사용할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                }
        }
    }

    private func accountField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.plain)
            .padding(12)
            .background(fieldBackground)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(0.14))
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch mode {
            case .signIn:
                try await auth.signIn(displayId: displayId, password: password)
            case .signUp:
                try await auth.signUp(displayId: displayId, password: password, nickname: nickname)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
