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
        case "expense-installments":
            if let wallet = store.ledger.activeWallets.first, let category = store.ledger.categories.first {
                let example = Expense(title: "Compra de ejemplo", cents: 6000000, firstMonth: Month(), installments: 6, walletID: wallet.id, categoryID: category.id, firstInstallment: 3)
                ExpenseForm(existing: example)
            }
        case "expense-other", "expense-shared":
            if let wallet = store.ledger.activeWallets.first, let category = store.ledger.categories.first {
                let example = Expense(title: "Compra de ejemplo", cents: 123450, firstMonth: Month(), walletID: wallet.id, categoryID: category.id, allocation: route == "expense-other" ? .mai : .shared)
                ExpenseForm(existing: example)
            } else { Text("Agregá un medio de pago para ver el formulario de ejemplo.") }
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
        case "category-breakdown":
            if let category = store.ledger.categories.first(where: { item in store.charges.contains { $0.expense.categoryID == item.id } }) {
                CategorySpendingView(categoryID: category.id, month: store.month, currency: store.currency)
            }
        case "wallets": WalletSettings()
        case "forecast": SpendingForecastView()
        case "reminders": ReminderSettingsView()
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
