import SwiftUI
import Charts
import UniformTypeIdentifiers

struct Tile<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 14) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(20).bolsilloCard() }
}

struct ExpenseCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
            VStack(alignment: .leading, spacing: 16) { content }
                .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20).bolsilloCard()
    }
}

private struct BlockingProgress: ViewModifier {
    let active: Bool
    let message: String
    func body(content: Content) -> some View {
        content
            .disabled(active)
            .interactiveDismissDisabled(active)
            .overlay {
                if active {
                    ZStack {
                        Palette.ink.opacity(0.16).ignoresSafeArea()
                        ProgressView(message)
                            .tint(Palette.accent).foregroundStyle(Palette.text)
                            .font(.subheadline.weight(.medium))
                            .padding(24).bolsilloCard(radius: 20)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                }
            }
    }
}
extension View {
    func blockingProgress(_ active: Bool, message: String) -> some View {
        modifier(BlockingProgress(active: active, message: message))
    }
}
