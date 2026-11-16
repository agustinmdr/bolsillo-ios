import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct BulkReviewView: View {
    @Environment(Store.self) private var store
    @State private var query = ""
    @State private var pendingOnly = true
    @State private var allMonths = true
    @State private var selection: Set<UUID> = []
    @State private var applying = false
    @State private var message = ""
    private var rows: [Expense] {
        store.ledger.expenses.filter { e in
            e.currency == store.currency && (!pendingOnly || e.needsReview) && (allMonths || e.occurrence(in: store.month) != nil) && (query.isEmpty || e.displayTitle.localizedStandardContains(query) || e.tags.localizedStandardContains(query))
        }.sorted { $0.firstMonth > $1.firstMonth }
    }
    var body: some View {
        BolsilloList {
            Section {
                Toggle("Solo pendientes de revisión", isOn: $pendingOnly)
                Toggle("Incluir todo el historial", isOn: $allMonths)
                NavigationLink("Reglas por comercio") { MerchantRulesView() }
                HStack { Button("Seleccionar resultados") { selection.formUnion(rows.map(\.id)) }; Spacer(); Button("Quitar selección") { selection = [] } }
                Text("\(selection.count) seleccionados · \(store.currency)").font(.subheadline.weight(.semibold))
                Text("Seleccionás compras completas. Los cambios de categoría o responsable también se aplican a sus cuotas en otros meses.").font(.caption).foregroundStyle(Palette.muted)
                if !message.isEmpty { Text(message).font(.caption) }
                if store.reviewUndo != nil { Button("Deshacer última revisión") { message = "Se restauraron \(store.undoReview()) compras. Las que cambiaron después se conservaron." } }
            }
            Section("\(rows.count) compras") {
                if rows.isEmpty { ContentUnavailableView("Sin pendientes", systemImage: "checkmark.circle") }
                ForEach(rows) { e in
                    Button {
                        if selection.contains(e.id) { selection.remove(e.id) } else { selection.insert(e.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selection.contains(e.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(Palette.accent).font(.title3)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(e.displayTitle).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.text)
                                Text("\(e.firstMonth.label) · \(money(e.cents, currency: e.currency))\(e.installments > 1 ? " total en \(e.installments) cuotas" : "")").font(.caption).foregroundStyle(Palette.muted)
                                Text(store.ledger.categories.first { $0.id == e.categoryID }?.name ?? "").font(.caption).foregroundStyle(Palette.muted)
                                AllocationBadge(allocation: e.allocation)
                            }
                        }
                    }.buttonStyle(.plain).accessibilityAddTraits(selection.contains(e.id) ? .isSelected : [])
                }
            }
        }.navigationTitle("Revisar gastos").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "Buscar comercio o etiqueta")
            .toolbar { Button("Cambiar \(selection.count)") { applying = true }.disabled(selection.isEmpty) }
            .sheet(isPresented: $applying) { BulkApplyView(ids: selection) { selection = [] } }
    }
}
