import SwiftUI
import Charts

struct PlanningView: View {
    @Environment(Store.self) private var store
    @State private var showBudget = false
    @State private var showIncome = false
    @State private var categoryID: UUID?
    @State private var amount = ""
    @State private var title = "Sueldo"
    var body: some View {
        BolsilloList {
            Section { PeriodPicker() }
            Section {
                Text("Próximos 6 meses").font(.headline)
                Chart(0..<6, id: \.self) { offset in
                    let m = store.month.adding(offset)
                    let total = store.ledger.charges(in: m, currency: store.currency).reduce(Int64(0)) { $0+$1.agusShare }
                    BarMark(x: .value("Mes", m.date, unit: .month), y: .value("Tu parte", Double(total)/100)).foregroundStyle(Palette.accent.gradient).cornerRadius(5)
                }.chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }.frame(height: 170)
                Text("Tu parte de compras y recurrentes ya cargados. No incluye gastos futuros que todavía no registraste.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section {
                ForEach(store.ledger.budgets.filter { $0.currency == store.currency }) { budget in
                    let category = store.ledger.categories.first { $0.id == budget.categoryID }
                    let spent = store.charges.filter { $0.expense.categoryID == budget.categoryID }.reduce(Int64(0)) { $0+$1.agusShare }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(category?.name ?? "Categoría").fontWeight(.medium); Spacer(); Text("\(Int(Double(spent)/Double(budget.cents)*100))%").foregroundStyle(spent > budget.cents ? Palette.danger : Palette.accent) }
                        ProgressView(value: min(max(Double(spent)/Double(budget.cents), 0), 1)).tint(spent > budget.cents ? Palette.danger : Palette.accent)
                        Text("\(money(spent, currency: store.currency)) de \(money(budget.cents, currency: store.currency))").font(.caption).foregroundStyle(Palette.muted)
                    }.padding(.vertical, 4).swipeActions { Button("Eliminar", role: .destructive) { store.commit { $0.budgets.removeAll { $0.id == budget.id } } } }
                }
                Button("Agregar o actualizar presupuesto") { amount = ""; categoryID = store.ledger.categories.first?.id; showBudget = true }
            } header: { Text("Presupuestos mensuales") } footer: { Text("Límites sobre tu parte personal. Se aplican a todos los meses. Actualizar una categoría reemplaza su límite.") }
            Section("Ingresos del mes") {
                ForEach(store.ledger.incomes.filter { $0.month == store.month && $0.currency == store.currency }) { income in
                    HStack { Text(income.title); Spacer(); Text(money(income.cents, currency: income.currency)) }.swipeActions { Button("Eliminar", role: .destructive) { store.commit { $0.incomes.removeAll { $0.id == income.id } } } }
                }
                Button("Agregar ingreso") { amount = ""; showIncome = true }
            }
            Section("Gastos fijos mensuales") {
                ForEach(store.charges.filter { $0.expense.recurring }) { charge in
                    ChargeRow(charge: charge)
                }
                Text("Los recurrentes generan un cargo por mes desde su primer resumen. El aporte personal al hogar se registra como Mío.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Compras en cuotas activas") {
                ForEach(store.charges.filter { $0.installmentProgress != nil }) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        ChargeRow(charge: c)
                        if let progress = c.installmentProgress { Text("\(progress.historical ? "Fin estimado" : "Termina"): \(progress.lastMonth.label)\(progress.historical ? " · Histórico sin proyección" : "")").font(.caption).foregroundStyle(Palette.muted) }
                    }
                }
            }
        }.navigationTitle("Planificar")
            .sheet(isPresented: $showBudget) { NavigationStack { BolsilloForm {
                Section("Elegí una categoría") { CategorySelectionGrid(categories: store.ledger.categories, selection: $categoryID) }
                Section("Límite mensual") { TextField("Límite en \(store.currency)", text: $amount).keyboardType(.decimalPad) }
            }.navigationTitle("Presupuesto").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showBudget = false } }; ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                if let categoryID, let cents = parseCents(amount) { store.commit { data in data.budgets.removeAll { $0.categoryID == categoryID && $0.currency == store.currency }; data.budgets.append(Budget(categoryID: categoryID, cents: cents, currency: store.currency)) }; if store.error == nil { showBudget = false } }
            }.disabled(parseCents(amount) == nil || categoryID == nil) } } } }
            .sheet(isPresented: $showIncome) { NavigationStack { BolsilloForm {
                TextField("Descripción", text: $title); TextField("Importe en \(store.currency)", text: $amount).keyboardType(.decimalPad)
                Text(store.month.label)
            }.navigationTitle("Ingreso").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showIncome = false } }; ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                if let cents = parseCents(amount) { store.commit { $0.incomes.append(Income(month: store.month, title: title, cents: cents, currency: store.currency)) }; if store.error == nil { showIncome = false } }
            }.disabled(parseCents(amount) == nil || title.isEmpty) } } } }
    }
}
