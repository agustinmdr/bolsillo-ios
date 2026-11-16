import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct RuleEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: MerchantRule?
    @State private var text = ""
    @State private var categoryID: UUID?
    @State private var ownerChange = false
    @State private var allocation: Allocation = .mine
    @State private var percent = 50.0
    var body: some View {
        NavigationStack { BolsilloList {
            Section("Si el nombre contiene") { TextField("Por ejemplo: Shell", text: $text); Text("Coincidencia de texto, sin distinguir acentos o mayúsculas.").font(.caption).foregroundStyle(Palette.muted) }
            Section("Asignar categoría") { CategorySelectionGrid(categories: store.ledger.categories, selection: $categoryID) }
            Section("Responsable opcional") {
                Toggle("También cambiar responsable", isOn: $ownerChange)
                if ownerChange {
                    Picker("Responsable", selection: $allocation) { ForEach(Allocation.allCases) { Text($0.title).tag($0) } }
                    if allocation == .shared { Text("Otra persona: \(Int(percent))%"); Slider(value: $percent, in: 0...100, step: 1) }
                }
            }
        }.navigationTitle("Regla").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                guard let categoryID else { return }
                var rule = MerchantRule(text: text.trimmingCharacters(in: .whitespaces), categoryID: categoryID, allocation: ownerChange ? allocation : nil, maiPercent: Int(percent))
                rule.id = existing?.id ?? UUID()
                store.commit { data in data.ops.rules.removeAll { $0.id == rule.id }; data.ops.rules.append(rule) }
                if store.error == nil { dismiss() }
            }.disabled(normalized(text).isEmpty || categoryID == nil) }
        }.onAppear { if let e = existing { text = e.text; categoryID = e.categoryID; ownerChange = e.allocation != nil; allocation = e.allocation ?? .mine; percent = Double(e.maiPercent) } }
        }
    }
}
