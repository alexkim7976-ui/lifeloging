import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var tracker: ActivityTracker?
    private weak var friendShare: FriendShareCoordinator?
    private var updater: SparkleUpdaterController?
    private var statsProvider: (() -> (focusRatio: Double, topApps: [AppUsage]))?
    private var cancellables = Set<AnyCancellable>()

    func setup(
        tracker: ActivityTracker,
        friendShare: FriendShareCoordinator,
        updater: SparkleUpdaterController,
        statsProvider: @escaping () -> (focusRatio: Double, topApps: [AppUsage])
    ) {
        self.tracker = tracker
        self.friendShare = friendShare
        self.updater = updater
        self.statsProvider = statsProvider

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarTitle()

        tracker.$isTracking
            .combineLatest(tracker.$currentAppName, tracker.$currentSegmentStart)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateMenuBarTitle()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .lifeloggerLanguageDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.buildMenu()
                self?.updateMenuBarTitle()
            }
            .store(in: &cancellables)

        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMenuBarTitle()
            }
            .store(in: &cancellables)

        buildMenu()
        setupPopover()
    }

    private func setupPopover() {
        guard let button = statusItem?.button else { return }
        let pop = NSPopover()
        pop.behavior = .transient
        popover = pop
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            statusItem?.popUpMenu(statusItem?.menu ?? NSMenu())
            return
        }

        guard let popover, let tracker, let statsProvider else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        let stats = statsProvider()
        popover.contentViewController = NSHostingController(
            rootView: AppLanguageRoot {
                MenuBarPopoverView(
                    tracker: tracker,
                    topApps: stats.topApps,
                    focusRatio: stats.focusRatio
                )
            }
        )
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    private func updateMenuBarTitle() {
        guard let tracker else { return }
        let icon = tracker.isTracking ? "●" : "○"
        let elapsed = elapsedString(since: tracker.currentSegmentStart)
        let appLabel = menuBarAppLabel(from: tracker.currentAppName)
        if tracker.isTracking, !appLabel.isEmpty {
            statusItem?.button?.title = "\(icon) \(appLabel) · \(elapsed)"
        } else {
            statusItem?.button?.title = "\(icon) \(elapsed)"
        }
        statusItem?.button?.toolTip = tracker.isTracking
            ? "LifeLogger · \(tracker.currentAppName)"
            : "LifeLogger · \(L10n.tr("menubar.paused"))"
    }

    private func menuBarAppLabel(from appName: String) -> String {
        guard !appName.isEmpty else { return "" }
        if appName.count <= 12 { return appName }
        return String(appName.prefix(11)) + "…"
    }

    private func elapsedString(since start: Date?) -> String {
        guard let start, tracker?.isTracking == true else { return "00:00" }
        let elapsed = Int(Date().timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: L10n.tr("menubar.toggle"),
            action: #selector(toggleTracking),
            keyEquivalent: "t"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let shareItem = NSMenuItem(
            title: L10n.tr("menubar.share"),
            action: #selector(shareWithFriend),
            keyEquivalent: "s"
        )
        shareItem.target = self
        menu.addItem(shareItem)

        let messageCenterItem = NSMenuItem(
            title: L10n.tr("menubar.messageCenter"),
            action: #selector(openMessageCenter),
            keyEquivalent: "m"
        )
        messageCenterItem.target = self
        menu.addItem(messageCenterItem)

        let systemShareItem = NSMenuItem(
            title: L10n.tr("menubar.shareToApps"),
            action: #selector(shareCurrentActivity),
            keyEquivalent: ""
        )
        systemShareItem.target = self
        menu.addItem(systemShareItem)

        let bloomieItem = NSMenuItem(
            title: L10n.tr("menubar.bloomieMessenger"),
            action: #selector(shareViaBloomie),
            keyEquivalent: ""
        )
        bloomieItem.target = self
        menu.addItem(bloomieItem)

        menu.addItem(.separator())

        let openItem = NSMenuItem(
            title: L10n.tr("menubar.open"),
            action: #selector(openDashboard),
            keyEquivalent: "d"
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(
            title: L10n.tr("menubar.checkUpdates"),
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        let quitItem = NSMenuItem(
            title: L10n.tr("menubar.quit"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleTracking() {
        tracker?.toggleTracking()
    }

    @objc private func shareWithFriend() {
        NSApp.activate(ignoringOtherApps: true)
        openDashboard()
        if let tracker {
            let snapshot = CurrentActivityShareService.snapshot(
                from: tracker,
                focusRatioToday: tracker.todayFocusRatio
            )
            friendShare?.presentShareSheet(snapshot: snapshot)
        } else {
            friendShare?.presentShareSheet()
        }
    }

    @objc private func openMessageCenter() {
        NSApp.activate(ignoringOtherApps: true)
        openDashboard()
        friendShare?.presentMessageCenter()
    }

    @objc private func shareCurrentActivity() {
        guard let tracker, let button = statusItem?.button else { return }
        let snapshot = CurrentActivityShareService.snapshot(
            from: tracker,
            focusRatioToday: tracker.todayFocusRatio
        )
        if MacShareService.share(
            snapshot: snapshot,
            senderName: BloomieMessageFormatter.defaultSenderName,
            relativeTo: button
        ) {
            button.toolTip = L10n.tr("share.otherApps")
        } else {
            button.toolTip = L10n.tr("activity.trackingHint.notTracking")
        }
    }

    @objc private func shareViaBloomie() {
        NSApp.activate(ignoringOtherApps: true)
        openDashboard()
        if let tracker {
            let snapshot = CurrentActivityShareService.snapshot(
                from: tracker,
                focusRatioToday: tracker.todayFocusRatio
            )
            friendShare?.presentShareSheet(snapshot: snapshot)
        } else {
            friendShare?.presentShareSheet()
        }
    }

    @objc private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func checkForUpdates() {
        updater?.checkForUpdates()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
