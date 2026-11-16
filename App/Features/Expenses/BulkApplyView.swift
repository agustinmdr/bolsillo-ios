import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct BulkApplyView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let ids: Set<UUID>
    var applied: () -> Void
    @State private var categoryID: UUID?
    @State private var changeAllocation = false
    @State private var allocation: Allocation = .mine
    @State private var percent = 50.0
    @State private var reviewed = true
    @State private var confirming = false
    var body: some View {
        NavigationStack {
            BolsilloList {
                Section("Cambios para \(ids.count) compras") {
                    Toggle("Marcar como revisadas", isOn: $reviewed)
                    Toggle("Cambiar responsable", isOn: $changeAllocation)
                    if changeAllocation {
                        Picker("Responsable", selection: $allocation) { ForEach(Allocation.allCases) { Text($0.title).tag($0) } }
                        if allocation == .shared { Text("Parte de otra persona: \(Int(percent))%"); Slider(value: $percent, in: 0...100, step: 1) }
                    }
                    Text("No cambia importes, fechas, tarjetas ni quién pagó.").font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Categoría") {
                    Button("Mantener la categoría actual") { categoryID = nil }
                    CategorySelectionGrid(categories: store.ledger.categories, selection: $categoryID)
                }
                Section("Vista previa de las compras seleccionadas") {
                    ForEach(store.ledger.expenses.filter { ids.contains($0.id) }) { e in
                        VStack(alignment: .leading, spacing: 4) { Text(e.displayTitle); Text("\(e.firstMonth.label) · \(money(e.cents, currency: e.currency))").font(.caption).foregroundStyle(Palette.muted) }
                    }
                }
            }.navigationTitle("Revisión masiva").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Aplicar") { confirming = true }.disabled(categoryID == nil && !changeAllocation && !reviewed) }
                }
                .confirmationDialog("¿Aplicar estos cambios a \(ids.count) compras?", isPresented: $confirming, titleVisibility: .visible) {
                    Button("Aplicar cambios") {
                        store.applyBulk(ids: ids, change: BulkChange(categoryID: categoryID, allocation: changeAllocation ? allocation : nil, maiPercent: Int(percent), markReviewed: reviewed))
                        if store.error == nil { applied(); dismiss() }
                    }
                }
        }
    }
}
