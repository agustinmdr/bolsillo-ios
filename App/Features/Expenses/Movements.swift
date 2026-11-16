import SwiftUI
import Charts
import UniformTypeIdentifiers

struct Movements: View {
    @Environment(Store.self) private var store
    @State private var query = ""
    @State private var allocation = "Todos"
    @State private var wallet = "Todas"
    @State private var editing: Expense?
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
                Picker("Tarjeta", selection: $wallet) { Text("Todas").tag("Todas"); ForEach(store.ledger.wallets) { Text($0.displayName).tag($0.id.uuidString) } }
            }
            Section("\(filtered.count) cargos · \(money(filtered.reduce(0) { $0+$1.cents }, currency: store.currency))") {
                if filtered.isEmpty { ContentUnavailableView("Sin gastos", systemImage: "tray", description: Text("Registrá un gasto o cambiá los filtros.")) }
                ForEach(filtered) { c in Button { editing = c.expense } label: { ChargeRow(charge: c).foregroundStyle(Palette.text) } }
            }
        }.navigationTitle("Gastos").searchable(text: $query, prompt: "Comercio, etiqueta o nota")
            .toolbar { Button { store.showAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nuevo gasto") }
            .sheet(item: $editing) { ExpenseForm(existing: $0) }
    }
}
