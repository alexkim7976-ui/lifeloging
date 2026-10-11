import AppKit
import SwiftUI
import Combine

@MainActor
final class ControlStripFallbackController: ObservableObject {
    static let shared = ControlStripFallbackController()

    private var panel: NSPanel?
    private var tracker: ActivityTracker?
    private var statsProvider: (() -> Double)?
    private var commandPaletteHandler: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()

    var isVisible: Bool { panel?.isVisible == true }

    private init() {}

    func setup(
        tracker: ActivityTracker,
        focusRatioProvider: @escaping () -> Double,
        openCommandPalette: @escaping () -> Void
    ) {
        self.tracker = tracker
        self.statsProvider = focusRatioProvider
        self.commandPaletteHandler = openCommandPalette

        guard FeatureMetricsStore.bool("ui-20", default: true) else { return }
        // 사용자가 직접 닫았으면 다음 실행 시 자동으로 다시 띄우지 않는다
        guard FeatureMetricsStore.bool("ui-20.active", default: true) else { return }
        if HardwareCapability.usesControlStripFallback {
            show()
        }
    }

    func show() {
        guard let tracker, let statsProvider else { return }
        if panel == nil {
            panel = makePanel(tracker: tracker, statsProvider: statsProvider)
        }
        guard let panel else { return }
        positionPanel(panel)
        panel.orderFrontRegardless()
        FeatureMetricsStore.setBool("ui-20.active", true)
    }

    func hide() {
        panel?.orderOut(nil)
        FeatureMetricsStore.setBool("ui-20.active", false)
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    private func makePanel(
        tracker: ActivityTracker,
        statsProvider: @escaping () -> Double
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 64),
            styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let host = NSHostingController(
            rootView: ControlStripHostView(
                controller: self,
                tracker: tracker,
                statsProvider: statsProvider
            )
        )
        panel.contentViewController = host
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let width: CGFloat = 520
        let height: CGFloat = 64
        let x = frame.midX - width / 2
        let y = frame.minY + 8
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    func openCommandPalette() {
        commandPaletteHandler?()
    }
}

private struct ControlStripHostView: View {
    @ObservedObject var controller: ControlStripFallbackController
    @ObservedObject var tracker: ActivityTracker
    let statsProvider: () -> Double

    var body: some View {
        ControlStripFallbackView(
            tracker: tracker,
            focusRatio: statsProvider(),
            onCommandPalette: { controller.openCommandPalette() },
            onClose: { controller.hide() }
        )
        .padding(4)
    }
}
