import SwiftUI
import Charts
import UniformTypeIdentifiers

struct Dashboard: View {
    @Environment(Store.self) private var store
    @AppStorage("dashboardAmountsVisible") private var amountsVisible = true
    @State private var editing: Expense?
    @State private var accountsExpanded = false
    @State private var showingIncome = false
    @State private var incomeTitle = "Sueldo"
    @State private var incomeAmount = ""
    @State private var incomeMonth = Month()
    @State private var incomeCurrency = "ARS"
    var overview: MonthlyOverview { store.ledger.monthlyOverview(in: store.month, currency: store.currency) }
    var total: Int64 { overview.totalExpenses }
    var own: Int64 { overview.personalExpenses }
    var income: Int64 { overview.income }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PeriodPicker(title: "Resumen a pagar").padding(18).bolsilloCard(radius: 24)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("Saldo disponible", systemImage: "banknote").font(.subheadline.weight(.medium)).foregroundStyle(Palette.muted)
                        Spacer()
                        Button { amountsVisible.toggle() } label: {
                            Image(systemName: amountsVisible ? "eye" : "eye.slash")
                                .font(.body).foregroundStyle(Palette.accent).frame(width: 44, height: 44)
                                .background(Palette.inset, in: Circle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(amountsVisible ? "Ocultar importes" : "Mostrar importes")
                            .accessibilityValue(amountsVisible ? "Visibles" : "Ocultos")
                    }
                    Text(amountsVisible ? (overview.incomeCount > 0 ? money(overview.available, currency: store.currency) : "—") : "••••")
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                        .foregroundStyle(amountsVisible && overview.incomeCount > 0 && overview.available < 0 ? Palette.danger : Palette.accent)
                        .accessibilityLabel(!amountsVisible ? "Saldo disponible oculto" : overview.incomeCount > 0 ? "Saldo disponible: \(money(overview.available, currency: store.currency))" : "Cargá tus ingresos para calcular el saldo disponible")
                    Text(!amountsVisible ? "Tocá el ojo para volver a ver los importes." : overview.incomeCount > 0 ? "Estimado: ingresos menos tu parte de los gastos." : "Agregá tu sueldo o ingresos para calcular el saldo.")
                        .font(.caption).foregroundStyle(Palette.muted)
                    BolsilloDivider()
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Total de gastos", systemImage: "arrow.up.right").font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                            Text(displayedAmount(total)).font(.headline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Button(action: beginIncome) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text("Sueldo e ingresos").font(.caption).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.8)
                                    Image(systemName: "plus.circle.fill").font(.caption).foregroundStyle(Palette.accent)
                                }
                                Text(displayedAmount(income)).font(.headline).foregroundStyle(Palette.text).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(amountsVisible ? "Sueldo e ingresos: \(money(income, currency: store.currency)). Agregar ingreso" : "Sueldo e ingresos ocultos. Agregar ingreso").disabled(store.loadFailed)
                    }
                    if overview.otherExpenses != 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) { Text("Tu parte").font(.caption); Text(displayedAmount(own)).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7) }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 5) { Text("De otra persona").font(.caption); Text(displayedAmount(overview.otherExpenses)).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7) }
                        }.foregroundStyle(Palette.muted).padding(12).background(Palette.inset, in: RoundedRectangle(cornerRadius: 14))
                    }
                }.foregroundStyle(Palette.text).padding(20).bolsilloCard(radius: 24)
                Button { store.showAdd = true } label: {
                    Label("Registrar gasto", systemImage: "plus").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15).foregroundStyle(Palette.onBrand).background(Palette.mint, in: Capsule())
                }.buttonStyle(.plain)
                NavigationLink { StatementsOverview() } label: {
                    HStack { Label("Tarjetas y resúmenes", systemImage: "creditcard"); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()) }.font(.subheadline.weight(.semibold)).padding(16).bolsilloCard()
                }.buttonStyle(.plain)
                MonthlySpendingCard(amountsVisible: amountsVisible)
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
                            Button { editing = charge.expense } label: { ChargeRow(charge: charge, amountsVisible: amountsVisible).foregroundStyle(Palette.text) }.buttonStyle(.plain)
                            if charge.id != recent.last?.id { BolsilloDivider().padding(.leading, 54) }
                        }
                        }.padding(16).bolsilloCard()
                    }
                }
                if total > 0 && amountsVisible {
                Tile {
                    Text("Por categoría").font(.headline)
                    Text("Categorías con gasto neto positivo; los reintegros se descuentan del total mensual.").font(.caption2).foregroundStyle(Palette.muted)
                        Chart(categoryTotals, id: \.0.id) { c, amount in
                            SectorMark(angle: .value("Importe", Double(amount)), innerRadius: .ratio(0.7), angularInset: 3).foregroundStyle(by: .value("Categoría", c.id.uuidString)).cornerRadius(5)
                        }.chartForegroundStyleScale(domain: store.ledger.categories.map { $0.id.uuidString }, range: store.ledger.categories.map { Palette.categoryColor($0) }).chartLegend(.hidden).frame(height: 160).accessibilityLabel("Distribución del gasto por categoría")
                        ForEach(categoryTotals.prefix(4), id: \.0.id) { c, amount in
                            HStack { Circle().fill(Palette.categoryColor(c)).frame(width: 9, height: 9); Label(c.name, systemImage: c.symbol).font(.subheadline); Spacer(); Text(displayedAmount(amount)).font(.subheadline.bold()) }
                        }
                }
                }
                Tile {
                    DisclosureGroup(isExpanded: $accountsExpanded) {
                    ForEach(store.ledger.activeWallets) { wallet in
                        let amount = store.charges.filter { $0.expense.walletID == wallet.id }.reduce(Int64(0)) { $0+$1.cents }
                        HStack { VStack(alignment: .leading) { Text(wallet.displayName).font(.subheadline); if wallet.isExtension { Text("Extensión").font(.caption).foregroundStyle(Palette.muted) } }; Spacer(); Text(displayedAmount(amount)).font(.subheadline.bold()) }
                    }.padding(.top, 12)
                    } label: { Label("Tarjetas y cuentas", systemImage: "creditcard").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.text) }
                }
            }.padding(20)
        }.bolsilloScreen().navigationTitle("Bolsillo").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { ExpenseForm(existing: $0) }
            .sheet(isPresented: $showingIncome) {
                NavigationStack {
                    BolsilloForm {
                        Section("Ingreso") {
                            TextField("Descripción", text: $incomeTitle)
                            TextField("Importe en \(incomeCurrency)", text: $incomeAmount).keyboardType(.decimalPad)
                            LabeledContent("Mes", value: incomeMonth.label)
                        }
                        Section { Text("Se suma a los ingresos de este mes. Podés consultar o eliminar los ingresos desde Planificar.").font(.caption).foregroundStyle(Palette.muted) }
                    }.navigationTitle("Agregar ingreso").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingIncome = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Guardar", action: saveIncome).disabled(parseCents(incomeAmount) == nil || incomeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.loadFailed)
                            }
                        }
                }
            }
    }
    private func displayedAmount(_ cents: Int64) -> String { amountsVisible ? money(cents, currency: store.currency) : "••••" }
    private func beginIncome() {
        incomeTitle = "Sueldo"; incomeAmount = ""; incomeMonth = store.month; incomeCurrency = store.currency
        showingIncome = true
    }
    private func saveIncome() {
        guard showingIncome, let cents = parseCents(incomeAmount), !incomeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let item = Income(month: incomeMonth, title: incomeTitle.trimmingCharacters(in: .whitespacesAndNewlines), cents: cents, currency: incomeCurrency)
        store.commit { $0.incomes.append(item) }
        if store.ledger.incomes.contains(where: { $0.id == item.id }) { showingIncome = false }
    }
    var categoryTotals: [(Category, Int64)] {
        store.ledger.categories.compactMap { cat in
            let sum = store.charges.filter { $0.expense.categoryID == cat.id }.reduce(Int64(0)) { $0+$1.cents }
            return sum > 0 ? (cat, sum) : nil
        }.sorted { $0.1 > $1.1 }
    }
}
