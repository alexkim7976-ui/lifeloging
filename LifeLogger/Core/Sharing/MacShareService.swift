import AppKit
import SwiftUI

/// macOS에 설치된 앱(메시지, 메일, AirDrop 등)을 통한 공유
@MainActor
enum MacShareService {
    static func shareItems(
        for snapshot: CurrentActivitySnapshot,
        senderName: String? = nil
    ) -> [Any] {
        guard snapshot.canShare else { return [] }

        let message = ActivityWebShareService.buildShareText(
            message: BloomieMessageFormatter.buildStatusLine(from: snapshot),
            snapshot: snapshot,
            senderName: senderName
        )

        var items: [Any] = [message]

        if let webURL = ActivityWebShareService.buildWebShareURL(from: snapshot, senderName: senderName) {
            items.append(webURL)
        }

        if let deepLink = LifeLoggerShareHelper.buildShareURL(from: snapshot) {
            items.append(deepLink)
        }

        return items
    }

    static func presentSharePicker(items: [Any], relativeTo view: NSView) {
        guard !items.isEmpty else { return }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    @discardableResult
    static func share(snapshot: CurrentActivitySnapshot, senderName: String?, relativeTo view: NSView) -> Bool {
        let items = shareItems(for: snapshot, senderName: senderName)
        guard !items.isEmpty else { return false }
        presentSharePicker(items: items, relativeTo: view)
        return true
    }

    @discardableResult
    static func shareViaAirDrop(snapshot: CurrentActivitySnapshot, senderName: String?) -> Bool {
        let items = shareItems(for: snapshot, senderName: senderName)
        guard !items.isEmpty else { return false }

        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            return false
        }
        guard service.canPerform(withItems: items) else {
            return false
        }

        service.perform(withItems: items)
        return true
    }
}

/// SwiftUI 버튼에서 macOS 공유 시트를 띄우기 위한 앵커
struct MacSharePickerAnchor: NSViewRepresentable {
    let items: [Any]
    @Binding var isPresented: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard isPresented, !items.isEmpty else { return }

        DispatchQueue.main.async {
            MacShareService.presentSharePicker(items: items, relativeTo: nsView)
            isPresented = false
        }
    }
}

struct MacShareButton<Label: View>: View {
    let snapshot: CurrentActivitySnapshot
    let senderName: String
    @ViewBuilder let label: () -> Label

    @State private var presentSharePicker = false

    private var items: [Any] {
        MacShareService.shareItems(for: snapshot, senderName: senderName)
    }

    var body: some View {
        Button {
            presentSharePicker = true
        } label: {
            label()
        }
        .disabled(items.isEmpty)
        .background {
            MacSharePickerAnchor(items: items, isPresented: $presentSharePicker)
                .frame(width: 1, height: 1)
        }
    }
}

struct AirDropShareButton<Label: View>: View {
    let snapshot: CurrentActivitySnapshot
    let senderName: String
    @ViewBuilder let label: () -> Label

    private var canShare: Bool {
        !MacShareService.shareItems(for: snapshot, senderName: senderName).isEmpty
    }

    var body: some View {
        Button {
            _ = MacShareService.shareViaAirDrop(snapshot: snapshot, senderName: senderName)
        } label: {
            label()
        }
        .disabled(!canShare)
    }
}
