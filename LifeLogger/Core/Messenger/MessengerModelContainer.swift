import SwiftData
import SwiftUI

enum MessengerModelContainer {
    static let shared: ModelContainer = makeContainer()

    @MainActor
    private static var _mainContext: ModelContext?

    @MainActor
    static var mainContext: ModelContext {
        if let _mainContext { return _mainContext }
        let context = ModelContext(shared)
        _mainContext = context
        return context
    }

    static var messengerStoreURL: URL {
        PrivacyDataStore.applicationSupportURL.appendingPathComponent("messenger.store")
    }

    private static func makeContainer() -> ModelContainer {
        try? PrivacyDataStore.ensureSecureDirectory()
        let schema = Schema([
            MessengerFriend.self,
            MessengerMessage.self,
            MessengerRoom.self
        ])
        let config = ModelConfiguration(
            url: messengerStoreURL,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            try? SecurityBootstrap.hardenMessengerStoreFiles()
            return container
        } catch {
            fatalError("Messenger SwiftData container failed: \(error)")
        }
    }
}
