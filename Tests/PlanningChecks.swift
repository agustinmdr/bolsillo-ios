import Foundation

func runPlanningChecks() throws {
    let jan = Month(year: 2026, month: 1), feb = jan.adding(1)
    var ledger = Ledger()
    let wallet = ledger.wallets[0].id, category = ledger.categories[0].id
    let native = Expense(title: "Plan nativo", cents: 10001, firstMonth: jan, installments: 3, walletID: wallet, categoryID: category, allocation: .shared, maiPercent: 40)
    let fixed = Expense(title: "Servicio", cents: 2500, firstMonth: feb, recurring: true, endMonth: feb.adding(1), walletID: wallet, categoryID: category)
    let ownOther = Expense(title: "Otra persona", cents: 9000, firstMonth: jan, walletID: wallet, categoryID: category, allocation: .mai)
    let historical = Expense(title: "Accesorio 01/04", cents: 1234, firstMonth: jan, walletID: wallet, categoryID: category, sourceKey: "planilla-2026-synthetic-1")
    var latest = historical; latest.id = UUID(); latest.title = "Accesorio 02/04"; latest.firstMonth = feb; latest.sourceKey = "planilla-2026-synthetic-2"
    ledger.expenses = [native, fixed, ownOther, historical, latest]
    ledger.incomes = [Income(month: jan, title: "Ingreso sintético", cents: 999999)]
    var captureLedger = Ledger()
    captureLedger.wallets[0].archived = true
    let captureBefore = try LedgerStorage.data(captureLedger)
    let capture = WalletCapture(amount: 100, merchant: "Ejemplo", currency: "ARS", walletID: captureLedger.wallets[0].id, date: jan.date)
    do { _ = try capture.apply(to: &captureLedger); fatalError("Aceptó una tarjeta quitada") }
    catch WalletCaptureError.archivedWallet { check(true, "Atajos rechaza tarjetas quitadas") }
    check(try LedgerStorage.data(captureLedger) == captureBefore, "Captura rechazada no modifica gastos ni referencias")
    captureLedger.wallets[0].archived = false
    check(try capture.apply(to: &captureLedger), "Restaurar permite volver a usar la misma tarjeta en Atajos")
    let original = try LedgerStorage.data(ledger)
    let total = ledger.forecast(startingAt: jan, count: 6, currency: "ARS", portion: .total)
    check(total.total(in: jan) == 3334+9000+1234, "Proyección conserva cargos registrados del primer mes")
    check(total.total(in: feb) == 3334+2500+1234, "No duplica cuota histórica ya cargada")
    check(total.total(in: feb.adding(1)) == 3333+2500+1234, "Proyecta nativas, fijos y una sola serie histórica")
    check(total.total(in: feb.adding(2)) == 1234 && total.total(in: feb.adding(3)) == 0, "Respeta fin de nativas, recurrentes e históricos")
    check(total.amounts.filter { $0.kind == .estimated }.reduce(0) { $0+$1.cents } == 2468, "Estima solo cuotas posteriores al último registro")
    check(ledger.forecast(startingAt: jan, count: 3, currency: "USD").amounts.allSatisfy { $0.cents == 0 }, "Proyección no mezcla monedas")
    let mine = ledger.forecast(startingAt: jan, count: 6, currency: "ARS")
    let other = ledger.forecast(startingAt: jan, count: 6, currency: "ARS", portion: .mai)
    check(total.months.allSatisfy { mine.total(in: $0)+other.total(in: $0) == total.total(in: $0) }, "Proyección personal y ajena conservan todos los centavos")
    check(total.releases.first { $0.expense.id == native.id }?.freedFrom == jan.adding(3), "Plan nativo libera desde el mes posterior a su última cuota")
    check(total.releases.first { $0.expense.id == latest.id }?.estimated == true, "Fin histórico distingue estimación de plan nativo")
    check(try LedgerStorage.data(ledger) == original, "Consultar proyección no crea ni modifica gastos")
    var duplicate = latest; duplicate.id = UUID(); duplicate.sourceKey = "planilla-2026-distinct-purchase"
    ledger.expenses.append(duplicate)
    let ambiguous = ledger.forecast(startingAt: feb.adding(1), count: 3, currency: "ARS")
    check(ambiguous.ambiguousSeries == 1 && !ambiguous.amounts.contains { $0.kind == .estimated && $0.cents != 0 }, "Compras indistinguibles se advierten y no se proyectan doble")
    var rebuilt = ledger
    rebuilt.expenses.removeLast()
    var rebuiltPlan = native; rebuiltPlan.id = UUID(); rebuiltPlan.title = "Accesorio"; rebuiltPlan.cents = 4936; rebuiltPlan.installments = 4
    rebuilt.expenses.append(rebuiltPlan)
    check(!rebuilt.forecast(startingAt: feb.adding(1), count: 3, currency: "ARS").amounts.contains { $0.kind == .estimated && $0.cents != 0 }, "Plan reconstruido como nativo no vuelve a estimarse desde históricos")
    rebuilt.expenses.removeLast(); rebuilt.wallets[0].archived = true
    check(!rebuilt.forecast(startingAt: feb.adding(1), count: 3, currency: "ARS").amounts.contains { $0.kind == .estimated && $0.cents != 0 }, "Tarjetas archivadas conservan historia pero no generan estimaciones nuevas")
    check(ledger.forecast(startingAt: jan, count: 500, currency: "ARS").months.count == 12, "Horizonte limitado a doce meses")
    let december = Month(year: 2026, month: 12)
    check(ledger.forecast(startingAt: december, count: 2, currency: "ARS").months.last == Month(year: 2027, month: 1), "Proyección cruza el año")

    var preferences = ReminderPreferences(); preferences.fixedEnabled = true
    preferences.daysBefore = 3; preferences.hour = 18; preferences.minute = 45
    preferences.fixedDays[fixed.id.uuidString] = 31
    let plan = ledger.fixedReminderPlan(preferences: preferences, now: jan.date)
    let first = plan.first { $0.month == feb }!
    check(Calendar.current.component(.day, from: first.dueDate) == 28 && Month(first.dueDate) == feb, "Día 31 se ajusta al último día de febrero")
    check(Calendar.current.component(.day, from: first.fireDate) == 25 && Calendar.current.component(.hour, from: first.fireDate) == 18 && Calendar.current.component(.minute, from: first.fireDate) == 45, "Aviso respeta anticipación, hora y minutos")
    check(plan.count == 2 && plan.allSatisfy { $0.month >= fixed.firstMonth && $0.month <= fixed.endMonth! }, "Recordatorios respetan inicio y fin de la recurrencia")
    check(Set(plan.map(\.id)).count == plan.count, "IDs de recordatorios fijos son estables y únicos")
    check(ledger.fixedReminderPlan(preferences: preferences, now: feb.adding(2).date).isEmpty, "No avisa gastos finalizados")
    preferences.fixedEnabled = false
    check(ledger.fixedReminderPlan(preferences: preferences, now: jan.date).isEmpty, "Fijos desactivados no programan avisos")
    preferences.fixedEnabled = true; preferences.fixedDays = [:]
    check(ledger.fixedReminderPlan(preferences: preferences, now: jan.date).isEmpty, "No inventa el vencimiento de un gasto fijo")
    preferences.fixedDays[fixed.id.uuidString] = 31; preferences.daysBefore = 0
    check(ledger.fixedReminderPlan(preferences: preferences, now: jan.date).first?.dueDate == feb.date(day: 28), "Aviso en el mismo día conserva fecha de vencimiento")
    let sameDay = ledger.fixedReminderPlan(preferences: preferences, now: jan.date).first!
    check(Calendar.current.isDate(sameDay.fireDate, inSameDayAs: sameDay.dueDate), "Anticipación cero usa el día del vencimiento")
    var leap = ledger
    var leapFixed = fixed; leapFixed.firstMonth = Month(year: 2028, month: 2); leapFixed.endMonth = nil
    leap.expenses = [leapFixed]
    let leapPlan = leap.fixedReminderPlan(preferences: preferences, now: leapFixed.firstMonth.date)
    check(leapPlan.first?.dueDate == leapFixed.firstMonth.date(day: 29), "Día 31 respeta febrero bisiesto")
    check(leapPlan.allSatisfy { $0.fireDate <= Calendar.current.date(byAdding: .month, value: 12, to: leapFixed.firstMonth.date)! }, "Avisos limitados a doce meses")
    let suite = "Bolsillo-reminder-tests-\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    check(ReminderPreferences.load(from: defaults) == ReminderPreferences(), "Configuración anterior conserva un día y las 10 de la mañana por defecto")
    preferences.save(to: defaults)
    check(ReminderPreferences.load(from: defaults) == preferences, "Preferencias se conservan al volver a abrir")
    defaults.set(Data("inválido".utf8), forKey: ReminderPreferences.key)
    check(ReminderPreferences.load(from: defaults) == ReminderPreferences(), "Preferencias corruptas recuperan valores seguros")
    ledger.wallets[0].dueDay = 1; ledger.wallets[0].dueMonthOffset = 1
    let cardPlan = ledger.cardReminderPlan(now: jan.date, daysBefore: 7, hour: 9, minute: 15)
    let card = cardPlan.first { $0.month == jan }!
    check(Calendar.current.component(.day, from: card.fireDate) == 25 && Calendar.current.component(.hour, from: card.fireDate) == 9 && Calendar.current.component(.minute, from: card.fireDate) == 15, "Tarjetas usan anticipación y horario configurados")
    ledger.wallets[0].archived = true
    check(ledger.cardReminderPlan(now: jan.date).isEmpty, "Tarjetas archivadas no avisan")
    check(ledger.cardReminderPlan(now: jan.date, daysBefore: -1).isEmpty, "Anticipación inválida no programa fechas incorrectas")
    check(try LedgerStorage.data(ledger).count > 0, "Planificación mantiene ledger válido y codificable")
}
