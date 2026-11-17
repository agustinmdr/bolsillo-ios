import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

enum MigrationResolution: String, CaseIterable, Identifiable {
    case link = "Vincular a gasto existente", expense = "Importar como gasto", income = "Importar como ingreso", opening = "Usar como saldo inicial compartido", ignore = "Conservar solo como referencia"
    var id: String { rawValue }
}

struct ResolveMigrationView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let candidate: MigrationCandidate
    @State private var mode: MigrationResolution = .ignore
    @State private var amount = ""
    @State private var title = ""
    @State private var currency = "ARS"
    @State private var date = Date()
    @State private var walletID: UUID?
    @State private var categoryID: UUID?
    @State private var allocation: Allocation = .mine
    @State private var paidBy: Person = .agus
    @State private var percent = 50.0
    @State private var linkedID: UUID?
    @State private var whoOwes: Person?
    @State private var confirming = false
    private var valid: Bool {
        switch mode {
        case .ignore: return true
        case .link: return linkedID != nil
        case .expense: return candidate.cents >= 0 && parseCents(amount) != nil && walletID != nil && categoryID != nil && !normalized(title).isEmpty
        case .income: return parseCents(amount) != nil && !normalized(title).isEmpty
        case .opening: return parseCents(amount) != nil && whoOwes != nil
        }
    }
    var body: some View {
        BolsilloList {
            Section("Fuente original") {
                Text(candidate.title).font(.headline)
                Text("\(candidate.source) · \(candidate.section)").font(.caption).foregroundStyle(Palette.muted)
                Text(money(candidate.cents, currency: candidate.currency))
                Text("No se sumó todavía. Elegí qué representa antes de confirmar.").font(.caption).foregroundStyle(Palette.warning)
                Picker("Resolver como", selection: $mode) { ForEach(MigrationResolution.allCases) { Text($0.rawValue).tag($0) } }
            }
            if mode == .link {
                Section("Coincidencias de mes e importe: revisá el concepto") {
                    let matches = store.ledger.matchingExpenses(for: candidate)
                    if matches.isEmpty { Text("No hay coincidencias de mes e importe. Conservá la referencia o revisá el gasto antes de importarlo.").font(.caption) }
                    ForEach(matches) { e in Button { linkedID = e.id } label: { HStack { Text(e.displayTitle); Spacer(); Image(systemName: linkedID == e.id ? "checkmark.circle.fill" : "circle") } } }
                    Text("Vincular no cambia el importe, categoría o responsable de ese gasto y no agrega otro cargo.").font(.caption).foregroundStyle(Palette.muted)
                }
            } else if mode != .ignore {
                Section("Confirmá los datos") {
                    if candidate.kind == "income" {
                        ForEach(store.ledger.incomes.filter { $0.month == candidate.month && $0.currency == candidate.currency && $0.cents == abs(candidate.cents) }) { income in
                            Text("Ya existe un ingreso con ese importe: \(income.title). Si es el mismo sueldo, conservá esta fila solo como referencia.").font(.caption).foregroundStyle(Palette.warning)
                        }
                    }
                    TextField("Descripción", text: $title)
                    TextField("Importe positivo", text: $amount).keyboardType(.decimalPad)
                    Picker("Moneda", selection: $currency) { Text("ARS").tag("ARS"); Text("USD").tag("USD") }
                    DatePicker(mode == .opening ? "Saldo anterior al mes" : "Mes", selection: $date, displayedComponents: .date)
                    if mode == .opening {
                        Picker("Quién debe", selection: $whoOwes) { Text("Elegí una opción").tag(Optional<Person>.none); Text("Me deben").tag(Optional(Person.mai)); Text("Yo debo").tag(Optional(Person.agus)) }
                        Text("Reemplaza el saldo anterior a ese mes. No lo importes además como gasto ni repitas el mismo saldo en varios meses.").font(.caption).foregroundStyle(Palette.warning)
                    }
                    if candidate.cents < 0 { Text("El original es negativo. Verificá si era una devolución o una anotación de deuda; un reintegro de tarjeta se registra desde Conciliar resumen, no como gasto positivo.").font(.caption).foregroundStyle(Palette.warning) }
                }
                if mode == .expense {
                    Section("Cuenta y responsable") {
                        Picker("Cuenta", selection: $walletID) { ForEach(store.ledger.activeWallets) { Text($0.displayName).tag(Optional($0.id)) } }
                        Picker("Pagado por", selection: $paidBy) { ForEach(Person.allCases) { Text($0.title).tag($0) } }
                        Picker("Responsable", selection: $allocation) { ForEach(Allocation.allCases) { Text($0.title).tag($0) } }
                        if allocation == .shared { Text("Otra persona: \(Int(percent))%"); Slider(value: $percent, in: 0...100, step: 1) }
                    }
                    Section("Categoría") { CategorySelectionGrid(categories: store.ledger.categories, selection: $categoryID) }
                }
            } else { Section { Text("Se conserva el origen como referencia resuelta, sin modificar gastos, ingresos ni deudas.").font(.subheadline) } }
            Button("Confirmar resolución") { confirming = true }.disabled(!valid)
        }.navigationTitle("Revisar fila").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = candidate.title; amount = editableAmount(abs(candidate.cents)); currency = candidate.currency; date = candidate.month.date
                categoryID = store.ledger.categories.first { $0.name == "Sin categorizar" }?.id
                paidBy = candidate.paidBy ?? .agus
                walletID = store.ledger.activeWallets.first { $0.name == (paidBy == .mai ? "Pagado por Mai" : "Efectivo / transferencia") }?.id ?? store.ledger.activeWallets.first?.id
                mode = !store.ledger.matchingExpenses(for: candidate).isEmpty ? .link : candidate.kind == "expense" || candidate.kind == "fixed" ? .expense : .ignore
            }
            .confirmationDialog("¿\(mode.rawValue)?", isPresented: $confirming, titleVisibility: .visible) { Button("Confirmar", action: resolve) }
    }
    private func resolve() {
        guard valid else { return }
        store.commit { data in
            guard data.ops.migrationResolutions[candidate.id] == nil else { return }
            switch mode {
            case .ignore: data.ops.migrationResolutions[candidate.id] = "reference"
            case .link: if let linkedID { data.ops.migrationResolutions[candidate.id] = "linked:\(linkedID)" }
            case .income:
                if let cents = parseCents(amount) {
                    data.incomes.append(Income(month: Month(date), title: title, cents: cents, currency: currency, sourceKey: candidate.id)); data.ops.migrationResolutions[candidate.id] = "income"
                }
            case .opening:
                if let cents = parseCents(amount), let whoOwes {
                    data.ops.openings.removeAll { $0.month == Month(date) && $0.currency == currency }
                    data.ops.openings.append(CoupleOpening(month: Month(date), currency: currency, cents: whoOwes == .mai ? cents : -cents)); data.ops.migrationResolutions[candidate.id] = "opening"
                }
            case .expense:
                if let cents = parseCents(amount), let walletID, let categoryID {
                    data.expenses.append(Expense(title: title, cents: cents, currency: currency, date: date, firstMonth: Month(date), walletID: walletID, categoryID: categoryID, allocation: allocation, maiPercent: Int(percent), paidBy: paidBy, notes: "Origen: \(candidate.source). \(candidate.section)", sourceKey: candidate.id, reviewed: true)); data.ops.migrationResolutions[candidate.id] = "expense"
                }
            }
        }
        if store.error == nil { dismiss() }
    }
}
