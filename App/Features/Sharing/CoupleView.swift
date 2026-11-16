import SwiftUI
import Charts

struct CoupleView: View {
    @Environment(Store.self) private var store
    @State private var showingPayment = false
    @State private var amount = ""
    @State private var from: Person = .mai
    @State private var selected: Expense?
    var balance: Int64 { store.ledger.coupleSummary(in: store.month, currency: store.currency).ending }
    var body: some View {
        BolsilloList {
            Section { PeriodPicker(); NavigationLink("Liquidación, saldo anterior y cierre") { CoupleClosingView() } }
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(balance == 0 ? "Están al día" : balance > 0 ? "Te deben" : "Debés a otra persona").font(.headline)
                    Text(money(abs(balance), currency: store.currency)).font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(Palette.accent).minimumScaleFactor(0.5).lineLimit(1)
                    Text("Saldo acumulado hasta este mes, después de las devoluciones. Incluye el saldo pendiente de meses anteriores.").font(.caption).foregroundStyle(Palette.muted)
                    LabeledContent("Saldo anterior", value: money(store.ledger.coupleSummary(in: store.month, currency: store.currency).opening, currency: store.currency)).font(.caption)
                    LabeledContent("Movimiento del mes", value: money(store.ledger.balance(in: store.month, currency: store.currency), currency: store.currency)).font(.caption)
                    Button("Registrar devolución") { from = balance >= 0 ? .mai : .agus; amount = ""; showingPayment = true }.buttonStyle(.borderedProminent).tint(Palette.mint).foregroundStyle(Palette.onBrand)
                    ShareLink(item: summary) { Label("Compartir resumen", systemImage: "square.and.arrow.up") }.font(.subheadline)
                }.padding(.vertical, 8)
            }
            Section("Tus gastos personales") { stat("Te corresponden", value: total(.mine)); Text("Son tuyos, aunque los haya pagado otra persona.").font(.caption).foregroundStyle(Palette.muted) }
            Section("Gastos de otra persona") { stat("Le corresponden", value: total(.mai)); ForEach(store.charges.filter { $0.expense.allocation == .mai }) { c in Button { selected = c.expense } label: { ChargeRow(charge: c).foregroundStyle(Palette.text) } } }
            Section("Compartidos") {
                stat("Total compartido", value: total(.shared))
                stat("Tu parte", value: store.charges.filter { $0.expense.allocation == .shared }.reduce(0) { $0+$1.agusShare })
                stat("Parte de otra persona", value: store.charges.filter { $0.expense.allocation == .shared }.reduce(0) { $0+$1.maiShare })
                ForEach(store.charges.filter { $0.expense.allocation == .shared }) { c in Button { selected = c.expense } label: { ChargeRow(charge: c).foregroundStyle(Palette.text) } }
            }
            Section("Devoluciones registradas") {
                ForEach(store.ledger.settlements.filter { $0.month == store.month && $0.currency == store.currency }) { payment in
                    HStack { Text(payment.from == .mai ? "Te devolvieron" : "Devolviste a otra persona"); Spacer(); Text(money(payment.cents, currency: payment.currency)) }
                        .swipeActions { Button("Eliminar", role: .destructive) { store.commit { $0.settlements.removeAll { $0.id == payment.id } } } }
                }
            }
        }.navigationTitle("Compartidos").sheet(item: $selected) { ExpenseForm(existing: $0) }
            .sheet(isPresented: $showingPayment) {
                NavigationStack { BolsilloForm {
                    Picker("Quién devuelve", selection: $from) { ForEach(Person.allCases) { Text($0.title).tag($0) } }
                    TextField("Importe en \(store.currency)", text: $amount).keyboardType(.decimalPad)
                    Text("La devolución se aplica a \(store.month.label). No se cuenta como ingreso ni como gasto.").font(.caption)
                }.navigationTitle("Devolución").toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingPayment = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                        if let cents = parseCents(amount) { store.commit { $0.settlements.append(Settlement(month: store.month, from: from, cents: cents, currency: store.currency)) }; if store.error == nil { showingPayment = false } }
                    }.disabled(parseCents(amount) == nil) }
                } }
            }
    }
    func total(_ a: Allocation) -> Int64 { store.charges.filter { $0.expense.allocation == a }.reduce(0) { $0+$1.cents } }
    func stat(_ label: String, value: Int64) -> some View { HStack { Text(label); Spacer(); Text(money(value, currency: store.currency)).fontWeight(.semibold) } }
    var summary: String {
        store.ledger.coupleText(in: store.month, currency: store.currency)
    }
}
