import FirebaseAuth
import Foundation
import Security

/// Firebase Auth가 macOS에서 자격 증명을 저장하려면 Keychain access group 설정이 필요합니다.
enum FirebaseAuthKeychainSupport {
    static func configureAccessGroupIfNeeded() {
        #if os(macOS)
        guard let accessGroup = resolvedKeychainAccessGroup() else {
            try? Auth.auth().useUserAccessGroup(nil)
            return
        }

        do {
            try Auth.auth().useUserAccessGroup(accessGroup)
        } catch {
            try? Auth.auth().useUserAccessGroup(nil)
        }
        #endif
    }

    #if os(macOS)
    private static func resolvedKeychainAccessGroup() -> String? {
        if let groups = entitlementValue(for: "keychain-access-groups") as? [String],
           let match = groups.first(where: { $0.contains("com.lifelogger.taehyeon") }) {
            return match
        }

        if let bundleID = Bundle.main.bundleIdentifier,
           let teamID = entitlementValue(for: "com.apple.developer.team-identifier") as? String {
            return "\(teamID).\(bundleID)"
        }

        return nil
    }

    private static func entitlementValue(for key: String) -> Any? {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        return SecTaskCopyValueForEntitlement(task, key as CFString, nil)
    }
    #endif
}
