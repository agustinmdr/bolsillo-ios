import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct RulePreviewView: View {
    @Environment(Store.self) private var store
    let ruleID: UUID
    @State private var pendingOnly = true
    @State private var editing = false
    @State private var confirming = false
    @State private var message = ""
    private var rule: MerchantRule? { store.ledger.ops.rules.first { $0.id == ruleID } }
    private var matches: [Expense] { guard let rule else { return [] }; return store.ledger.expenses.filter { (!pendingOnly || $0.needsReview) && rule.matches($0) } }
    var body: some View {
        BolsilloList {
            if let rule {
                Section {
                    Text("\(rule.text) → \(store.ledger.categories.first { $0.id == rule.categoryID }?.name ?? "")").font(.headline)
                    Toggle("Solo gastos pendientes", isOn: $pendingOnly)
                    Text("\(matches.count) compras de todo el historial, en todas sus monedas. Se cambia la categoría y se marcan revisadas.\(rule.allocation.map { " Responsable: \($0.title)." } ?? " Se conserva el responsable.")").font(.caption).foregroundStyle(Palette.muted)
                    if !message.isEmpty { Text(message).font(.caption) }
                    Button("Aplicar a las coincidencias") { confirming = true }.disabled(matches.isEmpty)
                    if store.reviewUndo != nil { Button("Deshacer revisión") { message = "Restauradas: \(store.undoReview()) compras." } }
                }
                ForEach(matches) { e in VStack(alignment: .leading, spacing: 4) { Text(e.displayTitle); Text("\(e.firstMonth.label) · \(money(e.cents, currency: e.currency))").font(.caption).foregroundStyle(Palette.muted) } }
            }
        }.navigationTitle("Vista previa").toolbar { Button("Editar") { editing = true }.disabled(rule == nil) }
            .sheet(isPresented: $editing) { RuleEditorView(existing: rule) }
            .confirmationDialog("¿Aplicar la regla a \(matches.count) compras?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Aplicar regla") {
                    if let rule {
                        let count = matches.count
                        store.applyBulk(ids: Set(matches.map(\.id)), change: BulkChange(categoryID: rule.categoryID, allocation: rule.allocation, maiPercent: rule.maiPercent))
                        if store.error == nil { message = "Se revisaron \(count) compras." }
                    }
                }
            }
    }
}
