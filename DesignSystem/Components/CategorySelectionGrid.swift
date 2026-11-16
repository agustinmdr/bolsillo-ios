import SwiftUI
import Charts
import UniformTypeIdentifiers

struct CategorySelectionGrid: View {
    let categories: [Category]
    @Binding var selection: UUID?
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var search = ""
    @State private var section: String?
    private var filtered: [Category] {
        categories.filter { category in
            (section == nil || category.section == section) &&
            (search.isEmpty || category.name.localizedStandardContains(search) || category.section.localizedStandardContains(search))
        }
    }
    private var columns: [GridItem] {
        typeSize >= .xxxLarge ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 94), spacing: 10)]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("Buscar categoría", text: $search).font(.subheadline).textInputAutocapitalization(.never).autocorrectionDisabled()
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) }.accessibilityLabel("Borrar búsqueda") }
            }.padding(12).background(Palette.inset, in: RoundedRectangle(cornerRadius: 12))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    sectionButton("Todas", value: nil)
                    ForEach(Array(Set(categories.map(\.section))).sorted(), id: \.self) { section in sectionButton(section, value: section) }
                }
            }
            if let selected = categories.first(where: { $0.id == selection }) {
                Text("Seleccionada: \(selected.name)").font(.caption).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.7)
            }
            if filtered.isEmpty { Text("No hay categorías que coincidan con la búsqueda.").font(.caption).foregroundStyle(Palette.muted) }
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(filtered) { category in
                let selected = selection == category.id
                Button { selection = category.id } label: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selected ? Palette.softGreen : Palette.inset)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            VStack(spacing: 10) {
                                Image(systemName: category.symbol)
                                    .font(.system(size: 21, weight: .medium))
                                    .foregroundStyle(selected ? Palette.accent : Palette.categoryColor(category))
                                    .frame(height: 28)
                                Text(category.name)
                                    .font(.caption.weight(selected ? .semibold : .medium))
                                    .foregroundStyle(Palette.text)
                                    .lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity)
                            }.padding(.horizontal, 8).padding(.vertical, 14)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Palette.accent : Palette.outline.opacity(0.7), lineWidth: selected ? 1.5 : 0.7))
                        .overlay(alignment: .topTrailing) {
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.accent)
                                    .padding(7).accessibilityHidden(true)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(category.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        }
    }
    private func sectionButton(_ title: String, value: String?) -> some View {
        Button { section = value } label: {
            Text(title).font(.caption.weight(.semibold)).lineLimit(1).fixedSize()
                .padding(.horizontal, 12).padding(.vertical, 9)
                .foregroundStyle(section == value ? Palette.onBrand : Palette.text)
                .background(section == value ? Palette.mint : Palette.inset, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(section == value ? .isSelected : [])
    }
}
