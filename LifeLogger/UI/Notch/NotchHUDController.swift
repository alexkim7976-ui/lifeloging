import AppKit
import SwiftUI

/// macOS 노치 영역 상단에 고정되는 플로팅 HUD (Notch Box 스타일)
@MainActor
final class NotchHUDController: ObservableObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var screenObserver: NSObjectProtocol?

    func show(tracker: ActivityTracker, friendShare: FriendShareCoordinator) {
        if panel == nil {
            createPanel(tracker: tracker, friendShare: friendShare)
            observeScreenChanges()
        }
        alignToNotch()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel(tracker: ActivityTracker, friendShare: FriendShareCoordinator) {
        let content = NotchHUDView()
            .environmentObject(tracker)
            .environmentObject(friendShare)
            .frame(width: 380, height: 120)

        let hosting = NSHostingView(rootView: AnyView(content))
        hostingView = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 120),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false

        self.panel = panel
    }

    private func alignToNotch() {
        guard let panel, let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let size = panel.frame.size
        let x = screenFrame.midX - (size.width / 2)
        let y = screenFrame.maxY - size.height

        panel.setFrame(
            NSRect(x: x, y: y, width: size.width, height: size.height),
            display: true
        )
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.alignToNotch()
            }
        }
    }
}
