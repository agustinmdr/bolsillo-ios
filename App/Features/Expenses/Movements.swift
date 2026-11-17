import SwiftUI
import Charts
import UniformTypeIdentifiers

struct Movements: View {
    @Environment(Store.self) private var store
    @State private var query = ""
    @State private var allocation = "Todos"
    @State private var wallet = "Todas"
    @State private var editing: Expense?
    @State private var pendingDeletion: Expense?
    var filtered: [Charge] {
        store.charges.filter { c in
            (query.isEmpty || (c.expense.title + c.expense.tags + c.expense.notes).localizedCaseInsensitiveContains(query)) &&
            (allocation == "Todos" || c.expense.allocation.rawValue == allocation) &&
            (wallet == "Todas" || c.expense.walletID.uuidString == wallet)
        }.sorted { $0.expense.date > $1.expense.date }
    }
    var body: some View {
        BolsilloList {
            Section { PeriodPicker(title: "Resumen a pagar")
                NavigationLink("Revisar y categorizar varios gastos") { BulkReviewView() }
                Picker("Responsable", selection: $allocation) { Text("Todos").tag("Todos"); ForEach(Allocation.allCases) { Text($0.title).tag($0.rawValue) } }
                Picker("Tarjeta o cuenta", selection: $wallet) { Text("Todas").tag("Todas"); ForEach(store.ledger.activeWallets) { Text($0.displayName).lineLimit(1).tag($0.id.uuidString) } }
            }
            Section("\(filtered.count) cargos · \(money(filtered.reduce(0) { $0+$1.cents }, currency: store.currency))") {
                if filtered.isEmpty { ContentUnavailableView("Sin gastos", systemImage: "tray", description: Text("Registrá un gasto o cambiá los filtros.")) }
                ForEach(filtered) { charge in
                    Button { editing = charge.expense } label: { ChargeRow(charge: charge).foregroundStyle(Palette.text) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                if charge.expense.recurring || charge.expense.installments > 1 {
                                    pendingDeletion = charge.expense
                                } else {
                                    Task { await store.deleteExpense(charge.expense.id) }
                                }
                            } label: { Label("Eliminar", systemImage: "trash") }
                            .tint(Palette.danger)
                        }
                }
            }
        }.navigationTitle("Gastos").searchable(text: $query, prompt: "Comercio, etiqueta o nota")
            .toolbar { Button { store.showAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nuevo gasto") }
            .sheet(item: $editing) { ExpenseForm(existing: $0) }
            .confirmationDialog("¿Eliminar \(pendingDeletion?.displayTitle ?? "este gasto")?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), titleVisibility: .visible) {
                if let expense = pendingDeletion {
                    Button(expense.recurring ? "Eliminar gasto recurrente" : "Eliminar compra y todas sus cuotas", role: .destructive) {
                        pendingDeletion = nil
                        Task { await store.deleteExpense(expense.id) }
                    }
                }
                Button("Cancelar", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text(pendingDeletion?.recurring == true
                     ? "Se eliminará este gasto de todos los meses, incluidos los anteriores y los futuros."
                     : "Se eliminarán todas las cuotas de esta compra, incluidas las de otros meses.")
            }
            .onChange(of: store.ledger.activeWallets.map(\.id)) { _, ids in
                if wallet != "Todas", !ids.contains(where: { $0.uuidString == wallet }) { wallet = "Todas" }
            }
            .blockingProgress(store.deletingExpenseID != nil, message: "Eliminando gasto…")
    }
}
