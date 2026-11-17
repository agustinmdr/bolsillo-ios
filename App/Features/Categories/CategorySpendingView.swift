import SwiftUI

struct CategorySpendingView: View {
    @Environment(Store.self) private var store
    let categoryID: UUID
    @State private var month: Month
    @State private var currency: String
    @State private var portion: SpendingPortion
    @State private var editing: Expense?
    init(categoryID: UUID, month: Month, currency: String, portion: SpendingPortion = .total) {
        self.categoryID = categoryID
        _month = State(initialValue: month); _currency = State(initialValue: currency); _portion = State(initialValue: portion)
    }
    private var category: Category? { store.ledger.categories.first { $0.id == categoryID } }
    private var charges: [Charge] {
        store.ledger.charges(in: month, currency: currency)
            .filter { $0.expense.categoryID == categoryID && (portion == .total || amount($0) != 0) }
            .sorted { $0.expense.date == $1.expense.date ? $0.id < $1.id : $0.expense.date > $1.expense.date }
    }
    private var total: Int64 { charges.reduce(0) { $0+amount($1) } }
    private var wallets: [Wallet] { store.ledger.wallets.filter { wallet in charges.contains { $0.expense.walletID == wallet.id } } }
    private func amount(_ charge: Charge) -> Int64 {
        switch portion { case .total: return charge.cents; case .mine: return charge.agusShare; case .mai: return charge.maiShare }
    }
    var body: some View {
        BolsilloList {
            Section {
                HStack {
                    Button { month = month.adding(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Mes anterior")
                    Spacer(minLength: 4)
                    Text(month.label.capitalized).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Button { month = month.adding(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Mes siguiente")
                }
                Picker("Moneda", selection: $currency) { Text("ARS").tag("ARS"); Text("USD").tag("USD") }.pickerStyle(.menu)
                Picker("Ver", selection: $portion) { ForEach(SpendingPortion.allCases) { Text($0.rawValue).lineLimit(1).truncationMode(.tail).tag($0) } }.pickerStyle(.menu)
            }
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let category {
                        Label { Text(category.name).foregroundStyle(Palette.text) } icon: { Image(systemName: category.symbol).foregroundStyle(Palette.categoryColor(category)) }.font(.headline).lineLimit(1).truncationMode(.tail)
                    }
                    Text(money(total, currency: currency)).font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    Text("\(charges.count) \(charges.count == 1 ? "movimiento" : "movimientos") · \(portion.rawValue)").font(.caption).foregroundStyle(Palette.muted)
                }.padding(.vertical, 8)
            } header: { Text("Desglose de la categoría") } footer: { Text("Se cuentan los cargos de este mes: la cuota correspondiente, los recurrentes y los ajustes. Los reintegros descuentan del total.") }
            if !wallets.isEmpty {
                Section("Por tarjeta o cuenta") {
                    ForEach(wallets) { wallet in
                        HStack {
                            Label(wallet.displayName, systemImage: wallet.isCreditCard ? "creditcard" : "banknote").lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 8)
                            Text(money(charges.filter { $0.expense.walletID == wallet.id }.reduce(0) { $0+amount($1) }, currency: currency)).fontWeight(.semibold).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        }.font(.subheadline)
                    }
                }
            }
            Section("Movimientos del mes") {
                if charges.isEmpty {
                    ContentUnavailableView("Sin gastos en esta categoría", systemImage: category?.symbol ?? "tray", description: Text("Probá otro mes, moneda o parte del gasto."))
                }
                ForEach(charges) { charge in
                    Button { editing = charge.expense } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ChargeRow(charge: charge)
                            if portion != .total {
                                HStack { Text(portion.rawValue); Spacer(); Text(money(amount(charge), currency: currency)).fontWeight(.semibold) }.font(.caption).foregroundStyle(Palette.accent).padding(.leading, 54)
                            }
                        }.foregroundStyle(Palette.text)
                    }.buttonStyle(.plain)
                }
            }
        }.navigationTitle(category?.name ?? "Categoría").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { ExpenseForm(existing: $0, displayMonth: month) }
            .blockingProgress(store.deletingExpenseID != nil, message: "Eliminando gasto…")
    }
}
