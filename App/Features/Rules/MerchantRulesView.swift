import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct MerchantRulesView: View {
    @Environment(Store.self) private var store
    @State private var creating = false
    var body: some View {
        BolsilloList {
            Section { Text("Guardá reglas como Shell → Nafta. Siempre vas a ver las coincidencias antes de aplicarlas; no cambian gastos por su cuenta.").font(.subheadline) }
            ForEach(store.ledger.ops.rules) { rule in
                NavigationLink { RulePreviewView(ruleID: rule.id) } label: {
                    VStack(alignment: .leading, spacing: 5) { Text(rule.text).font(.headline); Text(store.ledger.categories.first { $0.id == rule.categoryID }?.name ?? "").font(.caption).foregroundStyle(Palette.muted) }
                }.swipeActions { Button("Eliminar regla", role: .destructive) { store.commit { $0.ops.rules.removeAll { $0.id == rule.id } } } }
            }
            if store.ledger.ops.rules.isEmpty { ContentUnavailableView("Creá tu primera regla", systemImage: "wand.and.stars", description: Text("Por ejemplo: Shell → Nafta o Farmacity → Farmacia.")) }
        }.navigationTitle("Reglas por comercio").toolbar { Button { creating = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $creating) { RuleEditorView() }
    }
}
