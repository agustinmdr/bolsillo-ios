import SwiftUI
import Charts
import UniformTypeIdentifiers

struct Dashboard: View {
    @Environment(Store.self) private var store
    @State private var editing: Expense?
    @State private var accountsExpanded = false
    var total: Int64 { store.charges.reduce(0) { $0 + $1.cents } }
    var own: Int64 { store.charges.reduce(0) { $0 + $1.agusShare } }
    var income: Int64 { store.ledger.incomes.filter { $0.month == store.month && $0.currency == store.currency }.reduce(0) { $0 + $1.cents } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PeriodPicker(title: "Resumen a pagar").padding(18).bolsilloCard(radius: 24)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Gastos del resumen").font(.subheadline).foregroundStyle(Palette.muted)
                    Text(money(total, currency: store.currency)).font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1).accessibilityLabel("Total del mes: \(money(total, currency: store.currency))")
                    HStack {
                        VStack(alignment: .leading, spacing: 6) { Text("Tu parte").font(.caption).foregroundStyle(Palette.muted); Text(money(own, currency: store.currency)).font(.subheadline.weight(.semibold)).minimumScaleFactor(0.7).lineLimit(1) }
                        Spacer()
                        Rectangle().fill(Palette.outline).frame(width: 1, height: 32).padding(.horizontal, 16).accessibilityHidden(true)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) { Text("Parte de otra persona").font(.caption).foregroundStyle(Palette.muted); Text(money(total-own, currency: store.currency)).font(.subheadline.weight(.semibold)).minimumScaleFactor(0.7).lineLimit(1) }
                    }.padding(16).background(Palette.inset, in: RoundedRectangle(cornerRadius: 16))
                }.padding(.horizontal, 4).padding(.top, 4).foregroundStyle(Palette.text)
                Button { store.showAdd = true } label: {
                    Label("Registrar gasto", systemImage: "plus").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15).foregroundStyle(Palette.onBrand).background(Palette.mint, in: Capsule())
                }.buttonStyle(.plain)
                NavigationLink { StatementsOverview() } label: {
                    HStack { Label("Tarjetas y resúmenes", systemImage: "creditcard"); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()) }.font(.subheadline.weight(.semibold)).padding(16).bolsilloCard()
                }.buttonStyle(.plain)
                MonthlySpendingCard()
                NavigationLink { ExcelReportView() } label: {
                    HStack { Label("Reporte Excel del mes", systemImage: "chart.bar.doc.horizontal"); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()) }.font(.subheadline.weight(.semibold)).padding(16).bolsilloCard()
                }.buttonStyle(.plain)
                NavigationLink { SpendingForecastView() } label: {
                    HStack { Label("Proyección de próximos meses", systemImage: "calendar.badge.clock"); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()) }.font(.subheadline.weight(.semibold)).padding(16).bolsilloCard()
                }.buttonStyle(.plain)
                NavigationLink { PlanningView() } label: {
                    Tile {
                        HStack {
                            Image(systemName: "chart.bar.xaxis").foregroundStyle(Palette.accent).frame(width: 42, height: 42).background(Palette.softGreen, in: RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 4) { Text("Planificar el mes").font(.subheadline.weight(.semibold)); Text("Presupuestos, ingresos y cuotas").font(.caption).foregroundStyle(Palette.muted) }
                            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Palette.muted)
                        }
                        if income > 0 { BolsilloDivider(); HStack { Text("Disponible personal").font(.caption).foregroundStyle(Palette.muted); Spacer(); Text(money(income-own, currency: store.currency)).font(.subheadline.bold()).foregroundStyle(income-own < 0 ? Palette.danger : Palette.accent) } }
                    }
                }.buttonStyle(.plain)
                if store.charges.isEmpty {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "sparkles").foregroundStyle(Palette.accent).font(.title3)
                        VStack(alignment: .leading, spacing: 6) { Text("Tu mes empieza acá").font(.headline); Text("Cargá tu primer gasto. Después vas a poder ver qué es tuyo, qué es de otra persona y qué comparten.").font(.subheadline).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
                    }.padding(.horizontal, 8).padding(.vertical, 10)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("Últimos gastos").font(.headline); Spacer(); Text("\(store.charges.count) este mes").font(.caption).foregroundStyle(Palette.muted) }.padding(.horizontal, 4)
                        VStack(spacing: 12) {
                        let recent = Array(store.charges.sorted { $0.expense.date > $1.expense.date }.prefix(3))
                        ForEach(recent) { charge in
                            Button { editing = charge.expense } label: { ChargeRow(charge: charge).foregroundStyle(Palette.text) }.buttonStyle(.plain)
                            if charge.id != recent.last?.id { BolsilloDivider().padding(.leading, 54) }
                        }
                        }.padding(16).bolsilloCard()
                    }
                }
                if total > 0 {
                Tile {
                    Text("Por categoría").font(.headline)
                    Text("Categorías con gasto neto positivo; los reintegros se descuentan del total mensual.").font(.caption2).foregroundStyle(Palette.muted)
                        Chart(categoryTotals, id: \.0.id) { c, amount in
                            SectorMark(angle: .value("Importe", Double(amount)), innerRadius: .ratio(0.7), angularInset: 3).foregroundStyle(by: .value("Categoría", c.id.uuidString)).cornerRadius(5)
                        }.chartForegroundStyleScale(domain: store.ledger.categories.map { $0.id.uuidString }, range: store.ledger.categories.map { Palette.categoryColor($0) }).chartLegend(.hidden).frame(height: 160).accessibilityLabel("Distribución del gasto por categoría")
                        ForEach(categoryTotals.prefix(4), id: \.0.id) { c, amount in
                            HStack { Circle().fill(Palette.categoryColor(c)).frame(width: 9, height: 9); Label(c.name, systemImage: c.symbol).font(.subheadline); Spacer(); Text(money(amount, currency: store.currency)).font(.subheadline.bold()) }
                        }
                }
                }
                Tile {
                    DisclosureGroup(isExpanded: $accountsExpanded) {
                    ForEach(store.ledger.activeWallets) { wallet in
                        let amount = store.charges.filter { $0.expense.walletID == wallet.id }.reduce(Int64(0)) { $0+$1.cents }
                        HStack { VStack(alignment: .leading) { Text(wallet.displayName).font(.subheadline); if wallet.isExtension { Text("Extensión").font(.caption).foregroundStyle(Palette.muted) } }; Spacer(); Text(money(amount, currency: store.currency)).font(.subheadline.bold()) }
                    }.padding(.top, 12)
                    } label: { Label("Tarjetas y cuentas", systemImage: "creditcard").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.text) }
                }
            }.padding(20)
        }.bolsilloScreen().navigationTitle("Bolsillo").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { ExpenseForm(existing: $0) }
    }
    var categoryTotals: [(Category, Int64)] {
        store.ledger.categories.compactMap { cat in
            let sum = store.charges.filter { $0.expense.categoryID == cat.id }.reduce(Int64(0)) { $0+$1.cents }
            return sum > 0 ? (cat, sum) : nil
        }.sorted { $0.1 > $1.1 }
    }
}
