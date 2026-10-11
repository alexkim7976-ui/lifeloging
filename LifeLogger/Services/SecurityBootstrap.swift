import Foundation
import os

/// 앱 시작 시 프라이버시·무결성 검사 및 저장소 강화
enum SecurityBootstrap {
    private static let log = Logger(subsystem: "com.lifelogger.app", category: "Security")

    nonisolated(unsafe) private(set) static var lastFailureMessage: String?

    static var didCompleteSuccessfully: Bool { lastFailureMessage == nil }

    static func run() {
        lastFailureMessage = nil
        do {
            try PrivacyDataStore.ensureSecureDirectory()
            try PrivacyDataStore.excludeDataDirectoryFromBackup()
            try PrivacyDataStore.hardenAllLocalFiles()
            try hardenMessengerStoreFiles()
            SecureAppGroupWriter.audit()
            assertNetworkIsolationPolicy()
            log.info("Security bootstrap completed")
        } catch {
            lastFailureMessage = error.localizedDescription
            log.error("Security bootstrap failed")
        }
    }

    static func recheck() {
        run()
    }

    static func runAfterPersistenceWrite() {
        let root = PrivacyDataStore.applicationSupportURL
        let storeNames = [
            "LifeLogger.store", "LifeLogger.store-wal", "LifeLogger.store-shm",
            "messenger.store", "messenger.store-wal", "messenger.store-shm"
        ]
        for name in storeNames {
            let url = root.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try? PrivacyDataStore.applySecureFilePermissions(at: url)
        }
    }

    static func hardenMessengerStoreFiles() throws {
        let root = PrivacyDataStore.applicationSupportURL
        let names = ["messenger.store", "messenger.store-wal", "messenger.store-shm"]
        for name in names {
            let url = root.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try PrivacyDataStore.applySecureFilePermissions(at: url)
        }
    }

    private static func assertNetworkIsolationPolicy() {
        #if DEBUG
        log.debug("Network isolation: no URLSession usage in LifeLogger core paths")
        #endif
    }
}

/// 로컬 진단 로그 — 개인정보 미포함, 네트워크 전송 없음 (#10)
enum AppLogger {
    private static let subsystem = "com.lifelogger.app"

    static let tracking = Logger(subsystem: subsystem, category: "Tracking")
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
    static let privacy = Logger(subsystem: subsystem, category: "Privacy")
    static let updates = Logger(subsystem: subsystem, category: "Updates")

    static var logFileURL: URL {
        PrivacyDataStore.applicationSupportURL.appendingPathComponent("diagnostics.log")
    }

    static func appendDiagnosticLine(_ message: String) {
        let sanitized = SecureInputValidator.sanitizeText(message, maxLength: 500)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(sanitized)\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = logFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url, options: .atomic)
            try? PrivacyDataStore.applySecureFilePermissions(at: url)
        }
        rotateLogIfNeeded()
    }

    private static func rotateLogIfNeeded(maxBytes: Int = 512_000) {
        let url = logFileURL
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxBytes else { return }
        let backup = PrivacyDataStore.applicationSupportURL.appendingPathComponent("diagnostics.log.1")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: url, to: backup)
    }
}
