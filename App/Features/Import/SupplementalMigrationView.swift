import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SupplementalMigrationView: View {
    @Environment(Store.self) private var store
    @State private var query = ""
    @State private var includeReferences = false
    private var candidates: [MigrationCandidate] {
        store.migrationCandidates.filter { store.ledger.ops.migrationResolutions[$0.id] == nil && (includeReferences || $0.kind != "reference") && (query.isEmpty || ($0.title + $0.source + $0.section).localizedStandardContains(query)) }
    }
    var body: some View {
        BolsilloList {
            Section {
                Text("Sueldos y gastos fijos explícitos ya se incorporan una sola vez al abrir la actualización. Acá revisás los demás importes sin duplicar lo que ya está cargado.").font(.subheadline)
                Text("\(store.ledger.ops.migrationResolutions.count) filas resueltas · \(candidates.count) pendientes visibles").font(.caption).foregroundStyle(Palette.muted)
                Toggle("Mostrar totales y referencias", isOn: $includeReferences)
                Text("Mudanza puede repetir consumos de tarjetas. Vinculá esas filas al gasto existente. Los totales, saldos y anotaciones repetidas no se suman por defecto.").font(.caption).foregroundStyle(Palette.warning)
            }
            ForEach(candidates) { candidate in
                NavigationLink { ResolveMigrationView(candidate: candidate) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(candidate.title).font(.subheadline.weight(.semibold)); Spacer(); Text(money(candidate.cents, currency: candidate.currency)).font(.caption) }
                        Text("\(candidate.month.label) · \(candidate.source)").font(.caption).foregroundStyle(Palette.muted)
                        if !store.ledger.matchingExpenses(for: candidate).isEmpty { Label("Hay coincidencias para vincular", systemImage: "link").font(.caption).foregroundStyle(Palette.accent) }
                        if candidate.kind == "reference" || candidate.kind == "note" { Text("Anotación: necesita interpretación").font(.caption).foregroundStyle(Palette.warning) }
                    }
                }
            }
            if candidates.isEmpty { ContentUnavailableView("Sin pendientes para este filtro", systemImage: "checkmark.circle") }
        }.navigationTitle("Completar planilla").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "Concepto, hoja o mes")
    }
}
