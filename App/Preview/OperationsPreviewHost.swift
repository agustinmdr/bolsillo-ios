import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

#if DEBUG
/// Entrada de QA para comprobar pantallas sin tocar datos ni automatizar gestos.
struct OperationsPreviewRoute: Identifiable { let name: String; var id: String { name } }
struct OperationsPreviewHost: View {
    @Environment(Store.self) private var store
    let route: String
    @ViewBuilder var body: some View {
        switch route {
        case "ownership":
            BolsilloList {
                Section("Vista de responsabilidades") {
                    ForEach(Allocation.allCases) { allocation in
                        if var example = store.ledger.expenses.first {
                            let _ = example.allocation = allocation
                            let _ = example.title = allocation == .mine ? "Supermercado" : allocation == .shared ? "Cena compartida" : "Compra de otra persona"
                            ChargeRow(charge: Charge(expense: example, month: store.month, cents: 2400000, number: 1))
                        }
                    }
                }
            }.navigationTitle("Responsabilidades").navigationBarTitleDisplayMode(.inline)
        case "expense": ExpenseForm()
        case "confirmed-december":
            BolsilloList {
                Section("Consumo noviembre · resumen diciembre") {
                    ForEach(store.ledger.charges(in: Month(year: 2026, month: 12), currency: "ARS").filter { $0.expense.purchaseMonth != nil }.prefix(3)) { ChargeRow(charge: $0) }
                }
                Section("Gastos fijos mensuales") {
                    ForEach(store.ledger.charges(in: Month(year: 2026, month: 12), currency: "ARS").filter { $0.expense.recurring }) { ChargeRow(charge: $0) }
                }
            }.navigationTitle("Diciembre 2026").navigationBarTitleDisplayMode(.inline)
        case "excel": ExcelReportView().task {
            if ProcessInfo.processInfo.arguments.contains("--export-excel-qa") { _ = await store.exportExcel() }
        }
        case "cloud": CloudSettingsView()
        case "review": BulkReviewView()
        case "rules": MerchantRulesView()
        case "rule-editor": RuleEditorView()
        case "statements": StatementsOverview()
        case "reconcile": StatementEditorView(walletID: store.ledger.wallets[0].id)
        case "schedule": CardScheduleView(walletID: store.ledger.wallets[0].id)
        case "couple": CoupleClosingView()
        case "migration": SupplementalMigrationView()
        case "backup": BackupSettingsView()
        default: Text("Vista previa desconocida")
        }
    }
}
#endif
