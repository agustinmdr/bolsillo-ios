import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct StatementsOverview: View {
    @Environment(Store.self) private var store
    var body: some View {
        BolsilloList {
            Section { PeriodPicker(title: "Resumen a pagar"); NavigationLink("Recordatorios de vencimiento") { ReminderSettingsView() } }
            Section("Tarjetas") {
                ForEach(store.ledger.creditCards) { wallet in
                    NavigationLink { StatementEditorView(walletID: wallet.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            VStack(alignment: .leading, spacing: 5) { Text(wallet.displayName).font(.headline); Text(money(store.ledger.recordedStatement(walletID: wallet.id, month: store.month, currency: store.currency), currency: store.currency)).font(.title3.weight(.semibold)).foregroundStyle(Palette.accent) }
                            if let due = wallet.dueDate(in: store.month) { Text("Vence \(due.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(Palette.muted) }
                            else { Text("Cierre y vencimiento sin configurar").font(.caption).foregroundStyle(Palette.muted) }
                            if let record = store.ledger.ops.statements.first(where: { $0.walletID == wallet.id && $0.month == store.month && $0.currency == store.currency }), let reported = record.reportedCents {
                                Text(reported == store.ledger.recordedStatement(walletID: wallet.id, month: store.month, currency: store.currency) ? "Resumen conciliado" : "Hay diferencias con el resumen").font(.caption).foregroundStyle(Palette.accent)
                            }
                        }
                    }
                }
            }
        }.navigationTitle("Tarjetas y resúmenes").navigationBarTitleDisplayMode(.inline)
            .toolbar { NavigationLink("Administrar") { WalletSettings() } }
    }
}
