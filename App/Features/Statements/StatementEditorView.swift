import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct StatementEditorView: View {
    @Environment(Store.self) private var store
    let walletID: UUID
    @State private var reported = ""
    @State private var paid = "0"
    @State private var showingAdjustment = false
    @State private var editingAdjustment: StatementAdjustment?
    @State private var message = ""
    private var recorded: Int64 { store.ledger.recordedStatement(walletID: walletID, month: store.month, currency: store.currency) }
    private var valid: Bool { (reported.isEmpty || parseSignedCents(reported) != nil) && (parseSignedCents(paid).map { $0 >= 0 } ?? false) }
    var body: some View {
        BolsilloList {
            Section {
                Text(store.ledger.wallets.first { $0.id == walletID }?.displayName ?? "Cuenta").font(.headline)
                Text("\(store.month.label) · \(store.currency)").font(.subheadline)
                NavigationLink("Configurar cierre y vencimiento") { CardScheduleView(walletID: walletID) }
                LabeledContent("Registrado en Bolsillo", value: money(recorded, currency: store.currency))
            }
            Section("Comparar con el resumen del banco") {
                VStack(alignment: .leading, spacing: 8) { Text("Total del resumen").font(.caption).foregroundStyle(Palette.muted); TextField("Importe del banco", text: $reported).keyboardType(.numbersAndPunctuation) }
                VStack(alignment: .leading, spacing: 8) { Text("Pago acumulado al banco").font(.caption).foregroundStyle(Palette.muted); TextField("0", text: $paid).keyboardType(.decimalPad) }
                if let total = parseSignedCents(reported) {
                    LabeledContent("Diferencia", value: money(total-recorded, currency: store.currency))
                    Text(total == recorded ? "Los importes coinciden." : "Revisá cargos faltantes, cuotas, impuestos y devoluciones.").font(.caption).foregroundStyle(total == recorded ? Palette.accent : Palette.warning)
                    if let paidCents = parseSignedCents(paid) {
                        LabeledContent(total-paidCents >= 0 ? "Pendiente de pago" : "Pago excedente", value: money(abs(total-paidCents), currency: store.currency))
                    }
                }
                Button("Guardar resumen y pago") {
                    store.commit { $0.putStatement(StatementRecord(walletID: walletID, month: store.month, currency: store.currency, reportedCents: parseSignedCents(reported), paidCents: parseSignedCents(paid) ?? 0)) }
                    if store.error == nil { message = "Resumen guardado." }
                }.disabled(!valid)
                if !message.isEmpty { Text(message).font(.caption) }
                Text("El pago al banco no se suma otra vez como gasto y no liquida deudas con otra persona. ‘Pagado’ es el acumulado que ingresás para este resumen, no un pago adicional.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Impuestos, intereses y reintegros") {
                Button("Agregar ajuste al resumen") { showingAdjustment = true }
                ForEach(store.ledger.ops.adjustments.filter { $0.walletID == walletID && $0.month == store.month && $0.currency == store.currency }) { adjustment in
                    Button { editingAdjustment = adjustment } label: { HStack { VStack(alignment: .leading) { Text(adjustment.title); Text(adjustment.kind.rawValue).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Text(money(adjustment.signedCents, currency: adjustment.currency)) }.foregroundStyle(Palette.text) }
                        .swipeActions { Button("Eliminar", role: .destructive) { Task { await store.deleteExpense(adjustment.id) } } }
                }
            }
            Section("Cargos registrados") {
                ForEach(store.charges.filter { $0.expense.walletID == walletID }) { ChargeRow(charge: $0) }
            }
        }.blockingProgress(store.deletingExpenseID != nil, message: "Eliminando gasto…").navigationTitle("Conciliar resumen").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let record = store.ledger.ops.statements.first(where: { $0.walletID == walletID && $0.month == store.month && $0.currency == store.currency }) { reported = record.reportedCents.map(editableAmount) ?? ""; paid = editableAmount(record.paidCents) }
            }
            .sheet(isPresented: $showingAdjustment) { AdjustmentEditor(walletID: walletID, month: store.month, currency: store.currency) }
            .sheet(item: $editingAdjustment) { AdjustmentEditor(walletID: walletID, month: store.month, currency: store.currency, existing: $0) }
    }
}
