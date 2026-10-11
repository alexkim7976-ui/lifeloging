import Foundation
import SwiftData

/// 원시 활동 데이터 저장 경로 및 권한 관리.
/// ~/Library/Application Support/LifeLogger (0700/0600)
enum PrivacyDataStore {
    static let directoryName = "LifeLogger"

    static var applicationSupportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    static func ensureSecureDirectory() throws {
        let url = applicationSupportURL
        var isDirectory: ObjCBool = false

        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
            )
        }

        try applyDirectoryPermissions(at: url)
    }

    static func excludeDataDirectoryFromBackup() throws {
        var url = applicationSupportURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    static func secureFileURL(named filename: String) throws -> URL {
        guard !filename.isEmpty,
              !filename.contains("/"),
              !filename.contains("\\"),
              !filename.contains("..") else {
            throw PrivacyStoreError.invalidFilename
        }
        return applicationSupportURL.appendingPathComponent(filename)
    }

    static func applySecureFilePermissions(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )
    }

    static func applyDirectoryPermissions(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o700))],
            ofItemAtPath: url.path
        )
    }

    /// 데이터 디렉터리 내 모든 파일/하위 폴더 권한 재적용
    static func hardenAllLocalFiles() throws {
        let root = applicationSupportURL
        guard FileManager.default.fileExists(atPath: root.path) else { return }

        try applyDirectoryPermissions(at: root)

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                try applyDirectoryPermissions(at: fileURL)
            } else {
                try applySecureFilePermissions(at: fileURL)
            }
        }
    }

    static var swiftDataStoreURL: URL {
        applicationSupportURL.appendingPathComponent("LifeLogger.store")
    }

    enum PrivacyStoreError: Error {
        case invalidFilename
    }
}

// MARK: - SwiftData Schema Versioning (#4)

enum LifeLoggerSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static let models: [any PersistentModel.Type] = [
        ActivitySegment.self,
        CategoryMappingRule.self
    ]
}

enum LifeLoggerMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [LifeLoggerSchemaV1.self]

    static let stages: [MigrationStage] = []
}

enum ModelContainerFactory {
    static func makeContainer() -> ModelContainer {
        do {
            try PrivacyDataStore.ensureSecureDirectory()
        } catch {
            AppLogger.persistence.error("Directory setup failed: \(error.localizedDescription, privacy: .public)")
        }

        let config = ModelConfiguration(
            url: PrivacyDataStore.swiftDataStoreURL,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: Schema(versionedSchema: LifeLoggerSchemaV1.self),
                migrationPlan: LifeLoggerMigrationPlan.self,
                configurations: config
            )
        } catch {
            AppLogger.persistence.error("Primary container failed: \(error.localizedDescription, privacy: .public)")
            AppLogger.appendDiagnosticLine("Primary container failed: \(error.localizedDescription)")
            return fallbackContainer(originalError: error, config: config)
        }
    }

    static func fallbackContainer(originalError: Error, config: ModelConfiguration) -> ModelContainer {
        let backupURL = PrivacyDataStore.applicationSupportURL
            .appendingPathComponent("LifeLogger.store.backup-\(Int(Date().timeIntervalSince1970))")
        let storeURL = PrivacyDataStore.swiftDataStoreURL
        if FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.copyItem(at: storeURL, to: backupURL)
            AppLogger.appendDiagnosticLine("Backed up store to \(backupURL.lastPathComponent)")
        }

        do {
            return try ModelContainer(
                for: Schema(versionedSchema: LifeLoggerSchemaV1.self),
                migrationPlan: LifeLoggerMigrationPlan.self,
                configurations: config
            )
        } catch {
            AppLogger.persistence.error("Fallback container failed: \(error.localizedDescription, privacy: .public)")
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(
                    for: Schema(versionedSchema: LifeLoggerSchemaV1.self),
                    migrationPlan: LifeLoggerMigrationPlan.self,
                    configurations: memoryConfig
                )
            } catch {
                preconditionFailure("In-memory container failed: \(error)")
            }
        }
    }
}
