import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct AdjustmentEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let walletID: UUID
    let month: Month
    let currency: String
    var existing: StatementAdjustment?
    @State private var title = ""
    @State private var amount = ""
    @State private var kind: AdjustmentKind = .fee
    @State private var categoryID: UUID?
    @State private var allocation: Allocation = .mine
    @State private var percent = 50.0
    var body: some View {
        NavigationStack { BolsilloList {
            Section("Ajuste") {
                Picker("Tipo", selection: $kind) { ForEach(AdjustmentKind.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Descripción", text: $title)
                TextField("Importe positivo en \(currency)", text: $amount).keyboardType(.decimalPad)
                Text(kind == .refund ? "Se resta del gasto, no se registra como ingreso." : "Se suma al gasto de este resumen.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Responsable") {
                Picker("Corresponde a", selection: $allocation) { ForEach(Allocation.allCases) { Text($0.title).tag($0) } }
                if allocation == .shared { Text("Parte de otra persona: \(Int(percent))%"); Slider(value: $percent, in: 0...100, step: 1) }
                Text("Asigná el mismo responsable y porcentaje de la compra original cuando sea un reintegro.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Categoría") { CategorySelectionGrid(categories: store.ledger.categories, selection: $categoryID) }
        }.navigationTitle("Ajuste de resumen").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                guard let cents = parseCents(amount), let categoryID else { return }
                var adjustment = StatementAdjustment(walletID: walletID, month: month, currency: currency, title: title, cents: cents, kind: kind, categoryID: categoryID, allocation: allocation, maiPercent: Int(percent), paidBy: existing?.paidBy ?? store.ledger.wallets.first { $0.id == walletID }?.owner ?? .agus)
                adjustment.id = existing?.id ?? UUID()
                store.commit { data in data.ops.adjustments.removeAll { $0.id == adjustment.id }; data.ops.adjustments.append(adjustment) }
                if store.error == nil { dismiss() }
            }.disabled(normalized(title).isEmpty || parseCents(amount) == nil || categoryID == nil) }
        }.onAppear {
            categoryID = existing?.categoryID ?? store.ledger.categories.first { $0.name == "Impuestos" }?.id ?? store.ledger.categories.first?.id
            if let e = existing { title = e.title; amount = editableAmount(e.cents); kind = e.kind; allocation = e.allocation; percent = Double(e.maiPercent) }
        } }
    }
}
