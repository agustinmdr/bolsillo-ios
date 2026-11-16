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
