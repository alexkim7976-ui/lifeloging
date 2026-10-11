import AppKit
import ApplicationServices
import Foundation

enum ContextEnrichmentEngine {
    nonisolated(unsafe) private static var lastSpaceIndex = 0
    nonisolated(unsafe) private static var lastSampleAt = Date.distantPast
    nonisolated(unsafe) private static var spaceObserver: NSObjectProtocol?

    static func bootstrap() {
        guard spaceObserver == nil else { return }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            lastSpaceIndex += 1
            FeatureMetricsStore.increment("space.changes")
        }
    }

    @MainActor
    static func enrich(
        appName: String,
        bundleID: String,
        windowTitle: String,
        category: ActivityCategory
    ) -> EnrichedActivitySample {
        let now = Date()
        let delta = max(0, now.timeIntervalSince(lastSampleAt))
        if lastSampleAt != .distantPast, delta > 0, delta < 5 {
            accumulateTime(from: delta, appName: appName, bundleID: bundleID, windowTitle: windowTitle)
        }
        lastSampleAt = now

        let monitor = NSScreen.main?.localizedName ?? "Main"
        let isFullScreen = detectFullScreen()
        let browserDomain = parseBrowserDomain(appName: appName, bundleID: bundleID, title: windowTitle)
        let documentName = parseDocumentName(appName: appName, title: windowTitle)
        let terminalCWD = parseTerminalCWD(appName: appName, title: windowTitle)
        let projectTag = resolveProjectTag(
            appName: appName,
            bundleID: bundleID,
            title: windowTitle,
            browserDomain: browserDomain,
            documentName: documentName,
            terminalCWD: terminalCWD
        )
        let windowCount = countWindows(for: bundleID)

        FeatureMetricsStore.setString("context.currentTag", projectTag ?? category.rawValue)
        FeatureMetricsStore.setString("context.currentApp", appName)
        if let browserDomain {
            FeatureMetricsStore.setString("context.browserDomain", browserDomain)
        }

        return EnrichedActivitySample(
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle,
            category: category,
            timestamp: now,
            monitorName: monitor,
            spaceIndex: lastSpaceIndex,
            isFullScreen: isFullScreen,
            projectTag: projectTag,
            browserDomain: browserDomain,
            documentName: documentName,
            terminalCWD: terminalCWD,
            windowCount: windowCount
        )
    }

    private static func accumulateTime(
        from delta: TimeInterval,
        appName: String,
        bundleID: String,
        windowTitle: String
    ) {
        FeatureMetricsStore.addTime("monitor.main", seconds: delta)
        FeatureMetricsStore.addTime("space.\(lastSpaceIndex)", seconds: delta)
        FeatureMetricsStore.addTime("app.\(appName)", seconds: delta)

        let lowerApp = appName.lowercased()
        if lowerApp.contains("safari") || bundleID.contains("safari") {
            FeatureMetricsStore.addTime("browser.safari", seconds: delta)
        } else if lowerApp.contains("chrome") || bundleID.contains("google.chrome") {
            FeatureMetricsStore.addTime("browser.chrome", seconds: delta)
        } else if lowerApp.contains("arc") {
            FeatureMetricsStore.addTime("browser.arc", seconds: delta)
        }

        if let domain = parseBrowserDomain(appName: appName, bundleID: bundleID, title: windowTitle) {
            FeatureMetricsStore.addTime("domain.\(domain)", seconds: delta)
        }
        if let tag = resolveProjectTag(
            appName: appName,
            bundleID: bundleID,
            title: windowTitle,
            browserDomain: parseBrowserDomain(appName: appName, bundleID: bundleID, title: windowTitle),
            documentName: parseDocumentName(appName: appName, title: windowTitle),
            terminalCWD: parseTerminalCWD(appName: appName, title: windowTitle)
        ) {
            FeatureMetricsStore.addTime("project.\(tag)", seconds: delta)
        }

        if lowerApp.contains("zoom") || lowerApp.contains("meet") || lowerApp.contains("teams") {
            FeatureMetricsStore.addTime("meeting.apps", seconds: delta)
            FeatureMetricsStore.setString("context.meeting", "active")
        }

        if lowerApp.contains("steam") || lowerApp.contains("game") {
            FeatureMetricsStore.addTime("entertainment.games", seconds: delta)
        }

        if lowerApp.contains("music") || lowerApp.contains("tv") {
            FeatureMetricsStore.addTime("media.playback", seconds: delta)
        }

        if lowerApp.contains("obs") || lowerApp.contains("screen") && windowTitle.lowercased().contains("record") {
            FeatureMetricsStore.addTime("recording.screen", seconds: delta)
        }
    }

    private static func detectFullScreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let pid = app.processIdentifier as pid_t?,
              AXIsProcessTrusted() else { return false }
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        ) == .success,
              let window = focusedWindow else { return false }
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            "AXFullScreen" as CFString,
            &value
        ) == .success,
              let full = value as? Bool else { return false }
        return full
    }

    private static func countWindows(for bundleID: String) -> Int {
        guard AXIsProcessTrusted(),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              let pid = app.processIdentifier as pid_t? else { return 0 }
        let appElement = AXUIElementCreateApplication(pid)
        var windowList: AnyObject?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowList
        ) == .success,
              let windows = windowList as? [AXUIElement] else { return 0 }
        return windows.count
    }

    static func parseBrowserDomain(appName: String, bundleID: String, title: String) -> String? {
        let lower = appName.lowercased()
        guard lower.contains("safari") || lower.contains("chrome") || lower.contains("arc")
                || lower.contains("firefox") || lower.contains("edge")
                || bundleID.contains("browser") else { return nil }

        if let host = title.split(separator: " ").first, title.contains(".") {
            let candidate = String(host).trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.contains(".") { return candidate.lowercased() }
        }
        if let range = title.range(of: #"[\w.-]+\.[a-z]{2,}"#, options: .regularExpression) {
            return String(title[range]).lowercased()
        }
        return nil
    }

    static func parseDocumentName(appName: String, title: String) -> String? {
        let docExtensions = [".pdf", ".key", ".numbers", ".pages", ".docx", ".xlsx", ".pptx", ".psd", ".fig"]
        let lowerTitle = title.lowercased()
        for ext in docExtensions where lowerTitle.contains(ext) {
            return title.components(separatedBy: " — ").first
                ?? title.components(separatedBy: " - ").first
                ?? title
        }
        if appName.lowercased().contains("figma") {
            return title.components(separatedBy: " – ").first ?? title
        }
        return nil
    }

    static func parseTerminalCWD(appName: String, title: String) -> String? {
        let lower = appName.lowercased()
        guard lower.contains("terminal") || lower.contains("iterm") || lower.contains("warp") else { return nil }
        if title.hasPrefix("~") { return NSHomeDirectory() + String(title.dropFirst()) }
        if title.hasPrefix("/") { return title.components(separatedBy: ":").first ?? title }
        if title.contains(" — ") {
            return title.components(separatedBy: " — ").last
        }
        return nil
    }

    static func parseXcodeProject(title: String) -> String? {
        if title.contains(".xcodeproj") {
            return title.components(separatedBy: " — ").first ?? title
        }
        if title.contains(" — ") {
            return title.components(separatedBy: " — ").first
        }
        return nil
    }

    static func parseVSCodeWorkspace(title: String) -> String? {
        if title.contains("Visual Studio Code") || title.contains("Cursor") {
            return title.components(separatedBy: " — ").first
                ?? title.components(separatedBy: " - ").first
        }
        return nil
    }

    static func parseGitRepo(from path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        var url = URL(fileURLWithPath: path)
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) {
                return url.lastPathComponent
            }
            url.deleteLastPathComponent()
            if url.path == "/" { break }
        }
        return nil
    }

    private static func resolveProjectTag(
        appName: String,
        bundleID: String,
        title: String,
        browserDomain: String?,
        documentName: String?,
        terminalCWD: String?
    ) -> String? {
        let lowerApp = appName.lowercased()
        if lowerApp.contains("xcode"), let p = parseXcodeProject(title: title) { return "xcode:\(p)" }
        if lowerApp.contains("code") || lowerApp.contains("cursor"), let w = parseVSCodeWorkspace(title: title) {
            return "ide:\(w)"
        }
        if let cwd = terminalCWD, let repo = parseGitRepo(from: cwd) { return "git:\(repo)" }
        if lowerApp.contains("finder"), !title.isEmpty { return "folder:\(title)" }
        if let doc = documentName { return "doc:\(doc)" }
        if let domain = browserDomain { return "web:\(domain)" }
        if lowerApp.contains("logic") { return "daw:logic" }
        if lowerApp.contains("final cut") { return "video:fcp" }
        if lowerApp.contains("resolve") { return "video:resolve" }
        if lowerApp.contains("photoshop") { return "design:photoshop" }
        if lowerApp.contains("figma") { return "design:figma" }
        if lowerApp.contains("docker") { return "dev:docker" }
        if lowerApp.contains("parallels") || lowerApp.contains("utm") { return "vm:\(appName)" }
        if lowerApp.contains("slack") { return "comm:slack" }
        if lowerApp.contains("discord") { return "comm:discord" }
        if lowerApp.contains("mail") { return "mail:\(title.prefix(40))" }
        if lowerApp.contains("zoom") || lowerApp.contains("meet") { return "meeting:\(appName)" }
        if lowerApp.contains("jupyter") { return "data:jupyter" }
        if lowerApp.contains("jira") { return "pm:jira" }
        return ProContextParser.proTag(appName: appName, title: title)
    }
}

enum ProContextParser {
    static func proTag(appName: String, title: String) -> String? {
        let rules: [(String, String)] = [
            ("xcode", "dev:compile"),
            ("github", "dev:pr"),
            ("figma", "design:figma"),
            ("pages", "write:pages"),
            ("preview", "research:pdf"),
            ("testflight", "qa:testflight"),
            ("zendesk", "support:zendesk"),
            ("salesforce", "sales:crm"),
            ("obs", "creator:obs"),
            ("excel", "admin:excel"),
            ("numbers", "admin:numbers"),
            ("zotero", "academic:zotero"),
            ("omnifocus", "tasks:omnifocus"),
            ("things", "tasks:things")
        ]
        let lower = appName.lowercased()
        for (needle, tag) in rules where lower.contains(needle) {
            if !title.isEmpty { return "\(tag):\(title.prefix(24))" }
            return tag
        }
        return nil
    }
}
