import SwiftUI
import Charts
import UniformTypeIdentifiers

struct ExpenseForm: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Expense?
    @State private var title = ""
    @State private var amount = ""
    @State private var currency = "ARS"
    @State private var date = Date()
    @State private var firstDate = Date()
    @State private var installments = 1
    @State private var recurring = false
    @State private var hasEnd = false
    @State private var endDate = Date()
    @State private var walletID: UUID?
    @State private var categoryID: UUID?
    @State private var allocation: Allocation = .mine
    @State private var payer: Person = .agus
    @State private var percent = 50.0
    @State private var notes = ""
    @State private var tags = ""
    @State private var deleting = false
    @State private var detailsExpanded = false
    @State private var reportedNumber = 1
    @State private var reportedTotal = 2
    @State private var autoMonth = true
    var isHistorical: Bool { existing?.historicalInstallment != nil }
    var isAdjustment: Bool { existing?.isAdjustment == true }
    var installmentCharge: Charge? {
        guard let cents = parseCents(amount), let walletID, let categoryID else { return nil }
        var preview = Expense(title: title, cents: cents, currency: currency, firstMonth: Month(firstDate), installments: isHistorical || recurring ? 1 : installments, recurring: !isHistorical && recurring, walletID: walletID, categoryID: categoryID)
        if isHistorical { preview.sourceKey = existing?.sourceKey; preview.reportedInstallment = ReportedInstallment(number: reportedNumber, total: reportedTotal) }
        let target = preview.occurrence(in: store.month) == nil ? preview.firstMonth : store.month
        return preview.occurrence(in: target)
    }
    var valid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && parseCents(amount) != nil && walletID != nil && categoryID != nil && (!hasEnd || Month(endDate) >= Month(firstDate)) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Label(isAdjustment ? "Importe del ajuste" : isHistorical ? "Importe de esta cuota" : recurring ? "Importe mensual" : "Total de la compra", systemImage: "creditcard").font(.subheadline.weight(.medium)).foregroundStyle(Palette.muted)
                            Spacer()
                            Picker("Moneda", selection: $currency) { Text("ARS").tag("ARS"); Text("USD").tag("USD") }
                                .pickerStyle(.menu).labelsHidden().padding(.horizontal, 6).background(Palette.softGreen, in: Capsule())
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("$").foregroundStyle(Palette.muted)
                            TextField("0,00", text: $amount).keyboardType(.decimalPad).accessibilityLabel("Importe total")
                        }.font(.system(size: 38, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6)
                        BolsilloDivider()
                        TextField("¿En qué gastaste?", text: $title).font(.title3.weight(.medium)).submitLabel(.done).padding(.vertical, 4)
                    }.padding(24).bolsilloCard(radius: 24)
                if let charge = installmentCharge { InstallmentDetail(charge: charge) }
                ExpenseCard(title: "Dónde y cuándo", symbol: "bag") {
                    LabeledContent("Tarjeta o cuenta") {
                        Picker("Tarjeta o cuenta", selection: $walletID) { ForEach(store.ledger.wallets.filter { !$0.isArchived || $0.id == existing?.walletID }) { Text($0.displayName).tag(Optional($0.id)) } }.pickerStyle(.menu).labelsHidden()
                    }
                    if store.ledger.activeWallets.isEmpty && existing == nil {
                        NavigationLink("Agregá una tarjeta o cuenta") { WalletSettings() }
                    }
                    LabeledContent("Pagado por") {
                        Picker("Pagado por", selection: $payer) { ForEach(Person.allCases) { Text($0.title).tag($0) } }.pickerStyle(.menu).labelsHidden()
                    }
                    BolsilloDivider()
                    if let purchaseMonth = existing?.purchaseMonth {
                        LabeledContent("Mes del consumo", value: purchaseMonth.label)
                        Text("El mes del resumen se configura por separado. No se informó el día exacto de compra.").font(.caption).foregroundStyle(Palette.muted)
                    } else {
                        DatePicker(isHistorical || recurring ? "Fecha de referencia" : "Fecha de compra", selection: $date, displayedComponents: .date)
                    }
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Text("¿De quién es?").lineLimit(1).layoutPriority(1)
                        Spacer(minLength: 0)
                        Menu {
                            Picker("Responsabilidad", selection: $allocation) {
                                ForEach(Allocation.allCases) { option in Label(option.title, systemImage: option.symbol).lineLimit(1).tag(option) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: allocation.symbol).fixedSize()
                                Text(allocation.title).lineLimit(1).truncationMode(.tail)
                                Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).fixedSize()
                            }.foregroundStyle(allocation.ownershipColor).frame(minHeight: 44)
                        }.accessibilityLabel("Responsabilidad").accessibilityValue(allocation.title)
                    }
                    if allocation == .shared {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text("Vos · \(100-Int(percent))%"); Spacer(); Text("Otra persona · \(Int(percent))%") }.font(.caption.weight(.semibold)).lineLimit(1).truncationMode(.tail)
                            Slider(value: $percent, in: 0...100, step: 1).accessibilityLabel("Porcentaje de la otra persona")
                        }
                    }
                    BolsilloDivider()
                    Label("Categoría", systemImage: "square.grid.2x2").font(.headline)
                    CategorySelectionGrid(categories: store.ledger.categories, selection: $categoryID)
                }.padding(20).bolsilloCard(radius: 24)
                ExpenseCard(title: "Cuotas y repetición", symbol: "calendar") {
                    if isAdjustment {
                        DatePicker("Mes del ajuste", selection: $firstDate, displayedComponents: .date)
                        Text("\(existing?.tags ?? "Ajuste"). El importe se aplica con el signo correspondiente al tipo configurado en el resumen.").font(.caption).foregroundStyle(Palette.muted)
                    } else if isHistorical {
                        DatePicker("Mes del cargo", selection: $firstDate, displayedComponents: .date)
                        Stepper("Cuota reportada: \(reportedNumber)", value: $reportedNumber, in: 1...reportedTotal)
                        Stepper("Total de cuotas: \(reportedTotal)", value: $reportedTotal, in: 2...120)
                            .onChange(of: reportedTotal) { _, total in reportedNumber = min(reportedNumber, total) }
                        Text("Editar estos datos no reconstruye ni duplica el plan original.").font(.caption).foregroundStyle(Palette.muted)
                    } else {
                    if existing == nil, store.ledger.wallets.first(where: { $0.id == walletID })?.closingDay != nil {
                        Toggle("Usar el cierre de la tarjeta", isOn: $autoMonth).onChange(of: autoMonth) { _, _ in suggestMonth() }
                    }
                    DatePicker("Primer mes de resumen", selection: $firstDate, displayedComponents: .date)
                        .disabled(existing == nil && autoMonth && store.ledger.wallets.first(where: { $0.id == walletID })?.closingDay != nil)
                    BolsilloDivider()
                    Toggle("Se repite cada mes", isOn: $recurring)
                    if recurring {
                        Toggle("Tiene mes de fin", isOn: $hasEnd)
                        if hasEnd { DatePicker("Último mes", selection: $endDate, displayedComponents: .date) }
                    } else {
                        Stepper("\(installments) \(installments == 1 ? "pago" : "cuotas")", value: $installments, in: 1...120)
                        if let cents = parseCents(amount), installments > 1 { Text("Aproximadamente \(money(cents / Int64(installments), currency: currency)) por mes. Última cuota en \(Month(firstDate).adding(installments-1).label).").font(.caption).foregroundStyle(Palette.muted) }
                    }
                    Text("Elegí el mes del resumen de la primera cuota, según el cierre de tu tarjeta.").font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !isAdjustment { ExpenseCard(title: "Un poco más de detalle", symbol: "text.alignleft") {
                    DisclosureGroup("Nota y etiquetas", isExpanded: $detailsExpanded) {
                        VStack(spacing: 16) {
                            TextField("Etiquetas, separadas por coma", text: $tags)
                            TextField("Agregá una nota", text: $notes, axis: .vertical).lineLimit(3...6)
                            if let original = existing?.originalTitle ?? (isHistorical ? existing?.title : nil) {
                                Text("Descripción original: \(original)").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }.padding(.top, 16)
                    }
                } }
                if existing != nil {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(isAdjustment ? "Los cambios se aplican a este ajuste del resumen." : isHistorical ? "Los cambios se aplican a este cargo histórico. Los otros meses de la planilla se conservan." : "Los cambios se aplican a toda la compra y sus cuotas, incluidos meses anteriores.").font(.caption).foregroundStyle(Palette.muted)
                        Button("Eliminar compra", role: .destructive) { deleting = true }.font(.subheadline.weight(.medium)).padding(.vertical, 8)
                    }.padding(.horizontal, 8)
                }
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively).bolsilloScreen()
                .navigationTitle(existing == nil ? "Nuevo gasto" : "Tu gasto").navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Palette.paper, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
                .safeAreaInset(edge: .bottom) {
                    Button(action: save) {
                        Label(existing == nil ? "Guardar gasto" : "Guardar cambios", systemImage: "checkmark")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                            .foregroundStyle(Palette.onBrand).background(Palette.mint.opacity(valid ? 1 : 0.45), in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain).disabled(!valid).padding(.horizontal, 20).padding(.vertical, 12).background(Palette.paper)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Listo") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
                }
                .confirmationDialog(isAdjustment ? "¿Eliminar este ajuste?" : isHistorical ? "¿Eliminar este cargo histórico?" : "¿Eliminar la compra y todas sus cuotas?", isPresented: $deleting, titleVisibility: .visible) { Button("Eliminar", role: .destructive) { if let existing { store.deleteExpense(existing.id); if store.error == nil { dismiss() } } } }
                .onAppear(perform: populate)
                .onChange(of: walletID) { _, id in if existing == nil, let w = store.ledger.wallets.first(where: { $0.id == id }) { payer = w.owner; suggestMonth() } }
                .onChange(of: date) { _, _ in suggestMonth() }
                .onChange(of: store.ledger.activeWallets.map(\.id)) { _, ids in
                    if existing == nil, walletID.map({ ids.contains($0) }) != true { walletID = ids.first }
                }
        }
    }
    private func suggestMonth() {
        guard existing == nil, autoMonth, let wallet = store.ledger.wallets.first(where: { $0.id == walletID }), wallet.closingDay != nil else { return }
        firstDate = wallet.suggestedStatementMonth(for: date).date
    }
    func populate() {
        walletID = existing?.walletID ?? store.ledger.activeWallets.first?.id
        categoryID = existing?.categoryID ?? store.ledger.categories.first(where: { $0.name == "Sin categorizar" })?.id ?? store.ledger.categories.first?.id
        firstDate = store.month.date
        autoMonth = existing == nil && store.month == Month(date)
        suggestMonth()
        guard let e = existing else { return }
        title = e.displayTitle; amount = String(format: "%.2f", Double(e.cents)/100).replacingOccurrences(of: ".", with: ",")
        if let report = e.historicalInstallment { reportedNumber = report.number; reportedTotal = report.total }
        currency = e.currency; date = e.date; firstDate = e.firstMonth.date; installments = e.installments; recurring = e.recurring
        hasEnd = e.endMonth != nil; endDate = e.endMonth?.date ?? e.firstMonth.date
        allocation = e.allocation; payer = e.paidBy; percent = Double(e.maiPercent); notes = e.notes; tags = e.tags
    }
    func save() {
        guard valid, let cents = parseCents(amount), let walletID, let categoryID else { return }
        if let existing, isAdjustment {
            store.commit { data in if let index = data.ops.adjustments.firstIndex(where: { $0.id == existing.id }) {
                data.ops.adjustments[index].title = title; data.ops.adjustments[index].cents = cents; data.ops.adjustments[index].walletID = walletID; data.ops.adjustments[index].categoryID = categoryID; data.ops.adjustments[index].month = Month(firstDate); data.ops.adjustments[index].currency = currency; data.ops.adjustments[index].allocation = allocation; data.ops.adjustments[index].maiPercent = Int(percent); data.ops.adjustments[index].paidBy = payer
            } }
            if store.error == nil { dismiss() }; return
        }
        var e = Expense(title: title.trimmingCharacters(in: .whitespaces), cents: cents, currency: currency, date: date, firstMonth: Month(firstDate), installments: recurring ? 1 : installments, recurring: recurring, endMonth: recurring && hasEnd ? Month(endDate) : nil, walletID: walletID, categoryID: categoryID, allocation: allocation, maiPercent: Int(percent), paidBy: payer, notes: notes, tags: tags)
        if let existing {
            e.id = existing.id; e.sourceKey = existing.sourceKey; e.originalTitle = existing.originalTitle; e.purchaseMonth = existing.purchaseMonth
            if isHistorical {
                e.installments = 1; e.recurring = false; e.endMonth = nil
                e.reportedInstallment = ReportedInstallment(number: reportedNumber, total: reportedTotal)
                e.originalTitle = existing.originalTitle ?? existing.title
            }
        }
        e.reviewed = true
        store.commit { data in if let i = data.expenses.firstIndex(where: { $0.id == e.id }) { data.expenses[i] = e } else { data.expenses.append(e) } }
        if store.error == nil { dismiss() }
    }
}
