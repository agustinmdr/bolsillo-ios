import SwiftUI
import UniformTypeIdentifiers
import AppIntents

struct CategorySettings: View {
    @Environment(Store.self) private var store
    @State private var selected: Category?
    @State private var breakdown: Category?
    @State private var editingCategories = false
    @State private var showing = false
    @State private var name = ""
    @State private var section = "Personal"
    @State private var symbol = "bag.fill"
    @State private var search = ""
    private var visibleCategories: [Category] { store.ledger.categories.filter { search.isEmpty || $0.name.localizedStandardContains(search) || $0.section.localizedStandardContains(search) } }
    private var symbols: [String] { Array(Set(Category.defaults.map(\.symbol) + ["iphone", "cart.fill", "heart.fill", "parkingsign.circle.fill"])).sorted() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PeriodPicker()
                Text(editingCategories ? "Tocá una categoría para editar su nombre, sección o ícono." : "Tocá una categoría para ver sus gastos y el desglose del mes.").font(.subheadline).foregroundStyle(Palette.muted)
                if visibleCategories.isEmpty { ContentUnavailableView.search(text: search) }
                ForEach(Array(Set(visibleCategories.map(\.section))).sorted(), id: \.self) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group).font(.headline).padding(.horizontal, 4)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                            ForEach(visibleCategories.filter { $0.section == group }) { category in
                                Button {
                                    if editingCategories { selected = category; name = category.name; section = category.section; symbol = category.symbol; showing = true }
                                    else { breakdown = category }
                                } label: {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Image(systemName: category.symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.categoryColor(category)).frame(width: 36, height: 36).background(Palette.categoryColor(category).opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                                        Text(category.name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.text)
                                            .lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
                                            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                                        if let examples = examples(for: category) { Text(examples).font(.caption2).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
                                        let charges = store.charges.filter { $0.expense.categoryID == category.id }
                                        Text(money(charges.reduce(0) { $0+$1.cents }, currency: store.currency)).font(.subheadline.weight(.medium)).foregroundStyle(Palette.accent).lineLimit(1).minimumScaleFactor(0.7)
                                        Text("\(charges.count) gastos este mes").font(.caption2).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.8)
                                    }.frame(maxWidth: .infinity, alignment: .topLeading).padding(16).bolsilloCard()
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(20)
        }.bolsilloScreen().navigationTitle("Categorías").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Buscar categoría o sección")
            .navigationDestination(item: $breakdown) { category in CategorySpendingView(categoryID: category.id, month: store.month, currency: store.currency) }
            .toolbar {
                Button(editingCategories ? "Listo" : "Editar") { editingCategories.toggle() }
                Button { selected = nil; name = ""; section = "Personal"; symbol = "bag.fill"; showing = true } label: { Image(systemName: "plus") }.accessibilityLabel("Agregar categoría") }
            .sheet(isPresented: $showing) { NavigationStack { BolsilloForm {
                Section("Organización") { TextField("Nombre", text: $name); TextField("Sección", text: $section) }
                Section("Elegí un ícono") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                        ForEach(symbols, id: \.self) { icon in
                            Button { symbol = icon } label: {
                                Image(systemName: icon).font(.system(size: 18, weight: .medium)).frame(width: 44, height: 44)
                                    .foregroundStyle(symbol == icon ? Palette.onBrand : Palette.accent)
                                    .background(symbol == icon ? Palette.mint : Palette.softGreen, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityLabel(icon).accessibilityAddTraits(symbol == icon ? .isSelected : [])
                        }
                    }.padding(.vertical, 8)
                }
            }.navigationTitle("Categoría").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showing = false } }; ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                store.commit { data in if let selected, let i = data.categories.firstIndex(where: { $0.id == selected.id }) { data.categories[i].name = name; data.categories[i].section = section; data.categories[i].symbol = symbol } else { data.categories.append(Category(name: name, symbol: symbol, section: section)) } }; if store.error == nil { showing = false }
            }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || section.trimmingCharacters(in: .whitespaces).isEmpty || store.ledger.categories.contains { $0.name == name && $0.id != selected?.id }) } } } }
    }
    private func examples(for category: Category) -> String? {
        switch category.name {
        case "Auto": return "Nafta, cochera y estacionamiento"
        case "Tecnología": return "Dispositivos y accesorios"
        case "Supermercado": return "Alimentos y compras del día"
        default: return nil
        }
    }
}
