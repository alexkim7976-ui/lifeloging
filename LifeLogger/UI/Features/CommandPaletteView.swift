import SwiftUI

struct CommandPaletteAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    let actions: [CommandPaletteAction]

    @State private var query = ""
    @FocusState private var focused: Bool

    private var filtered: [CommandPaletteAction] {
        guard !query.isEmpty else { return actions }
        return actions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField(L10n.tr("features.commandPalette.placeholder"), text: $query)
                .textFieldStyle(.plain)
                .padding(12)
                .liquidGlassInsetPanel(cornerRadius: 10)
                .focused($focused)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filtered) { item in
                        Button {
                            item.action()
                            isPresented = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.systemImage)
                                    .frame(width: 20)
                                Text(item.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                            .foregroundStyle(LiquidGlassStyle.bodyText)
                        }
                        .buttonStyle(.plain)
                        .liquidGlassInsetPanel(cornerRadius: 8)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(20)
        .frame(width: 460)
        .liquidGlassCard(strong: true)
        .onAppear { focused = true }
    }
}
