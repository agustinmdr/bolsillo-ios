import Foundation

var checks = 0
func check(_ condition: @autoclosure () throws -> Bool, _ name: String) {
    do { guard try condition() else { fatalError("Falló: \(name)") }; checks += 1 }
    catch { fatalError("Falló: \(name): \(error)") }
}
var ledger = Ledger()
let november = Month(year: 2026, month: 11)
let wallet = ledger.wallets[0].id
let category = ledger.categories[0].id
var e = Expense(title: "Compra", cents: 10000, firstMonth: november, installments: 3, walletID: wallet, categoryID: category, allocation: .shared)
check(e.occurrence(in: november.adding(-1)) == nil, "No cobra antes de la primera cuota")
check(e.occurrence(in: november)?.cents == 3334, "Distribuye primer centavo")
check(e.occurrence(in: november.adding(1))?.cents == 3333, "Cuota cruza diciembre")
check(e.occurrence(in: november.adding(2))?.number == 3, "Cuota cruza año")
check(e.occurrence(in: november.adding(3)) == nil, "Termina la compra")
check((0..<3).reduce(Int64(0)) { $0 + e.occurrence(in: november.adding($1))!.cents } == 10000, "Suma de cuotas exacta")
for cents: Int64 in [1, 2, 99, 10000, 9999999] {
    for count in [1, 2, 3, 12, 120] {
        e.cents = cents; e.installments = count
        let charges = (0..<count).map { e.occurrence(in: november.adding($0))! }
        check(charges.reduce(0) { $0+$1.cents } == cents, "Conservación de centavos")
        check(charges.allSatisfy { $0.maiShare + $0.agusShare == $0.cents }, "Reparto conserva total")
    }
}
e.cents = 10000; e.installments = 1
check(e.occurrence(in: november)!.balance == 5000, "Compartido pagado por Agus")
e.paidBy = .mai
check(e.occurrence(in: november)!.balance == -5000, "Compartido pagado por Mai")
e.allocation = .mine
check(e.occurrence(in: november)!.balance == -10000, "Mai paga gasto de Agus")
e.allocation = .mai
check(e.occurrence(in: november)!.balance == 0, "Mai paga gasto propio")
e.paidBy = .agus
check(e.occurrence(in: november)!.balance == 10000, "Tarjeta prestada a Mai")
ledger.expenses = [e]
ledger.settlements.append(Settlement(month: november, from: .mai, cents: 3000, currency: "ARS"))
check(ledger.balance(in: november, currency: "ARS") == 7000, "Devolución reduce deuda")
check(ledger.balance(in: november, currency: "USD") == 0, "No mezcla monedas")
e.recurring = true; e.endMonth = november.adding(2)
check(e.occurrence(in: november.adding(2)) != nil, "Incluye último mes recurrente")
check(e.occurrence(in: november.adding(3)) == nil, "Corta recurrente")
check(parseCents("1.234,56") == 123456, "Importe argentino")
check(parseCents("0") == nil && parseCents("-10") == nil && parseCents("abc") == nil, "Rechaza importes inválidos")
check(parseCents("12abc") == nil && parseCents("1,234") == nil, "No acepta texto parcial ni precisión ambigua")
e.title = "Cena, \"Mai\"\ncompartida"; ledger.expenses = [e]
let text = CSV.export(ledger.charges(in: november, currency: "ARS"), ledger: ledger)
let imported = try CSV.preview(text, ledger: ledger)
check(imported.count == 1 && imported[0].title == e.title, "CSV preserva comillas, comas y saltos")
ledger.expenses = imported
let reimported = try CSV.preview(text, ledger: ledger)
check(reimported.isEmpty, "Reimportación idempotente")
let decoded = try JSONDecoder().decode(Ledger.self, from: JSONEncoder().encode(ledger))
try decoded.validate()
check(decoded.expenses[0].title == e.title, "Respaldo JSON conserva datos")
var invalid = decoded
invalid.expenses[0].firstMonth.month = 13
do { try invalid.validate(); fatalError("Aceptó un mes inválido") } catch { checks += 1 }
invalid = decoded
invalid.expenses[0].maiPercent = 101
do { try invalid.validate(); fatalError("Aceptó un reparto inválido") } catch { checks += 1 }
invalid = decoded
invalid.expenses[0].walletID = UUID()
do { try invalid.validate(); fatalError("Aceptó una tarjeta inexistente") } catch { checks += 1 }
let historical = CSV.header.joined(separator: ",") + "\n" + (1...3).map {
    "sample-\($0),2026-11,Compra de ejemplo \($0),10000,ARS,ICBC VISA,Sin categorizar,Mío,Agustín,Ejemplo sintético"
}.joined(separator: "\n")
let migration = try CSV.preview(historical, ledger: Ledger())
check(migration.count == 3, "Importación de planilla completa")
check(migration.allSatisfy { $0.installments == 1 && !$0.recurring && $0.allocation == .mine }, "Histórico no crea cuotas duplicadas ni infiere deudas")
var merged = Ledger()
let personal = Expense(title: "Gasto ya existente", cents: 15000, firstMonth: november, walletID: merged.wallets[0].id, categoryID: merged.categories[0].id)
merged.expenses = [personal]
merged.expenses.append(contentsOf: try CSV.preview(historical, ledger: merged))
check(merged.expenses.count == 4 && merged.expenses.contains { $0.id == personal.id }, "Importación conserva gastos existentes")
let secondPass = try CSV.preview(historical, ledger: merged)
check(secondPass.isEmpty, "Segunda importación histórica no duplica cargos")
check(ReportedInstallment.parse("Accesorio 18/18")?.cleanTitle == "Accesorio", "Separa cuota del título")
check(ReportedInstallment.parse("Comercio 01/03 ejemplo")?.cleanTitle == "Comercio ejemplo", "Conserva texto posterior a cuota")
check(ReportedInstallment.parse("Compra 13/12") == nil && ReportedInstallment.parse("Compra 00/03") == nil, "Rechaza cuotas fuera de rango")
check(ReportedInstallment.parse("Compra 01/01") == nil && ReportedInstallment.parse("Compra 01/999") == nil, "No confunde pago único ni plan excesivo")
var snapshot = Expense(title: "Compra de ejemplo 10/18", cents: 1234500, firstMonth: november, walletID: wallet, categoryID: category, sourceKey: "planilla-2026-11-5-3")
let beforeCents = snapshot.occurrence(in: november)!.cents
check(snapshot.displayTitle == "Compra de ejemplo", "Título histórico limpio sin mutación")
check(snapshot.title == "Compra de ejemplo 10/18", "Conserva descripción original")
check(snapshot.occurrence(in: november)!.installmentProgress?.number == 10, "Número reportado, no 1/1")
check(snapshot.occurrence(in: november)!.installmentProgress?.remaining == 8, "Cuotas restantes reportadas")
check(snapshot.occurrence(in: november)!.installmentProgress?.lastMonth == november.adding(8), "Fin estimado cruza año")
check(snapshot.occurrence(in: november.adding(1)) == nil, "Mostrar cuota no proyecta ni duplica histórico")
snapshot.originalTitle = snapshot.title; snapshot.title = snapshot.displayTitle
snapshot.reportedInstallment = ReportedInstallment(number: 10, total: 18)
let restoredSnapshot = try JSONDecoder().decode(Expense.self, from: JSONEncoder().encode(snapshot))
check(restoredSnapshot.historicalInstallment?.number == 10 && restoredSnapshot.originalTitle == "Compra de ejemplo 10/18", "Metadatos históricos persisten al editar título")
check(restoredSnapshot.occurrence(in: november)!.cents == beforeCents, "Presentación no cambia importe histórico")
var native = Expense(title: "Compra 10/18", cents: 10000, firstMonth: november, installments: 3, walletID: wallet, categoryID: category)
check(native.displayTitle == "Compra 10/18", "No interpreta texto libre de gastos nativos")
check(native.occurrence(in: november.adding(1))!.installmentProgress?.number == 2, "Número real de cuota nativa")
check(native.occurrence(in: november.adding(2))!.installmentProgress?.remaining == 0, "Última cuota sin pendientes")
native.recurring = true
check(native.occurrence(in: november)!.installmentProgress == nil, "Recurrentes no se muestran como plan de cuotas")
let oldSnapshotData = try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: JSONEncoder().encode(Expense(title: "Viejo 02/06", cents: 10000, firstMonth: november, walletID: wallet, categoryID: category, sourceKey: "planilla-2026-old"))))
let legacySnapshot = try JSONDecoder().decode(Expense.self, from: oldSnapshotData)
check(legacySnapshot.displayTitle == "Viejo", "Lee datos anteriores sin campos nuevos")
var captured = Ledger()
let captureDate = Date(timeIntervalSince1970: 1794844800)
let capture = WalletCapture(amount: Decimal(string: "1234.56")!, merchant: "  Supermercado  ", currency: "ARS", walletID: captured.wallets[0].id, date: captureDate)
let firstCapture = try capture.apply(to: &captured)
check(firstCapture && captured.expenses.count == 1, "Captura de pago genera un solo gasto")
check(captured.expenses[0].cents == 123456 && captured.expenses[0].title == "Supermercado", "Importe exacto y comercio normalizado")
check(captured.expenses[0].allocation == .mine && captured.expenses[0].installments == 1 && !captured.expenses[0].recurring, "No infiere reparto ni cuotas")
check(captured.categories.first { $0.id == captured.expenses[0].categoryID }?.name == "Sin categorizar", "Categoría explícita pendiente de revisión")
captured.expenses[0].tags = "Revisado"
let retry = try capture.apply(to: &captured)
check(!retry && captured.expenses.count == 1, "Reejecución inmediata no duplica pago")
var later = WalletCapture(amount: Decimal(string: "1234.56")!, merchant: "Supermercado", currency: "ARS", walletID: captured.wallets[0].id, date: captureDate.addingTimeInterval(11))
let laterResult = try later.apply(to: &captured)
check(laterResult && captured.expenses.count == 2, "Compra igual posterior al intervalo no se descarta")
later.eventID = "bank-event-unique"
let withID = try later.apply(to: &captured)
let retryWithID = WalletCapture(amount: later.amount, merchant: later.merchant, currency: later.currency, walletID: later.walletID, date: later.date.addingTimeInterval(1000), eventID: later.eventID)
let retryID = try retryWithID.apply(to: &captured)
check(withID && !retryID && captured.expenses.count == 3, "ID estable elimina repetición incluso fuera de ventana")
let usdCapture = WalletCapture(amount: 15, merchant: "Otro", currency: "USD", walletID: captured.wallets[0].id, date: captureDate, statementMonth: november.adding(1))
_ = try usdCapture.apply(to: &captured)
check(captured.expenses.last?.currency == "USD" && captured.expenses.last?.firstMonth == november.adding(1), "Moneda y mes de resumen explícitos")
for invalidAmount: Decimal in [0, -10, Decimal(string: "1.001")!, 1_000_000_001, .nan] {
    do {
        let badCapture = WalletCapture(amount: invalidAmount, merchant: "Comercio", currency: "ARS", walletID: captured.wallets[0].id, date: captureDate)
        _ = try badCapture.apply(to: &captured); fatalError("Aceptó importe Wallet inválido")
    } catch { checks += 1 }
}
let countBeforeErrors = captured.expenses.count
for bad in [WalletCapture(amount: 10, merchant: " ", currency: "ARS", walletID: captured.wallets[0].id, date: captureDate), WalletCapture(amount: 10, merchant: "Comercio", currency: "EUR", walletID: captured.wallets[0].id, date: captureDate), WalletCapture(amount: 10, merchant: "Comercio", currency: "ARS", walletID: UUID(), date: captureDate)] {
    do { _ = try bad.apply(to: &captured); fatalError("Aceptó datos Wallet inválidos") } catch { checks += 1 }
}
check(captured.expenses.count == countBeforeErrors, "Errores no modifican gastos")
try captured.validate()
var reports = Ledger()
reports.assignCategoryColors()
let categoryColors = reports.categories.map { ($0.id, $0.colorIndex!) }
check(Set(reports.categories.compactMap(\.colorIndex)).count == reports.categories.count, "Cada categoría inicial tiene un color distinto")
reports.categories[0].name = "Nombre nuevo"
reports.categories.reverse()
reports.categories.append(Category(name: "Nueva", symbol: "gift.fill", section: "Personal"))
reports.assignCategoryColors()
check(categoryColors.allSatisfy { old in reports.categories.first { $0.id == old.0 }?.colorIndex == old.1 }, "Renombrar, ordenar y agregar no cambia colores existentes")
let firstCategory = reports.categories[0].id
let secondCategory = reports.categories[1].id
reports.expenses = [
    Expense(title: "Plan", cents: 10000, firstMonth: november, installments: 3, walletID: reports.wallets[0].id, categoryID: firstCategory, allocation: .shared),
    Expense(title: "Histórico", cents: 2000, firstMonth: november, walletID: reports.wallets[0].id, categoryID: secondCategory, allocation: .mai, sourceKey: "planilla-2026-test"),
    Expense(title: "Recurrente", cents: 1500, firstMonth: november.adding(-1), recurring: true, endMonth: november.adding(1), walletID: reports.wallets[0].id, categoryID: secondCategory),
    Expense(title: "Dólares", cents: 900, currency: "USD", firstMonth: november, walletID: reports.wallets[0].id, categoryID: firstCategory)
]
let monthly = reports.monthlySpending(endingAt: november.adding(3), count: 6, currency: "ARS", portion: .total)
func sumMonth(_ month: Month, _ rows: [MonthlyCategoryAmount]) -> Int64 { rows.filter { $0.month == month }.reduce(0) { $0+$1.cents } }
check(Set(monthly.map(\.month)).count == 6 && monthly.first?.month == november.adding(-2), "Reporte muestra seis meses cronológicos, incluido cambio de año")
check(sumMonth(november, monthly) == 6834, "Apila cuota mensual más histórico y recurrente, sin sumar USD")
check(sumMonth(november.adding(1), monthly) == 4833, "Histórico no se replica en mes siguiente")
check(sumMonth(november.adding(2), monthly) == 3333 && sumMonth(november.adding(3), monthly) == 0, "Terminan cuotas y recurrentes; conserva meses vacíos")
check(monthly.filter { $0.month == november && $0.categoryID == firstCategory }.first?.cents == 3334, "Categoría usa el cargo de cuota, no total de compra")
let mineReport = reports.monthlySpending(endingAt: november.adding(3), count: 6, currency: "ARS", portion: .mine)
let maiReport = reports.monthlySpending(endingAt: november.adding(3), count: 6, currency: "ARS", portion: .mai)
check(monthly.allSatisfy { total in total.cents == mineReport.first { $0.id == total.id }!.cents + maiReport.first { $0.id == total.id }!.cents }, "Reportes personales suman el total por categoría y mes")
check(sumMonth(november, reports.monthlySpending(endingAt: november, count: 1, currency: "USD", portion: .total)) == 900, "Reporte de USD independiente")
check(reports.monthlySpending(endingAt: november, count: 0, currency: "ARS", portion: .total).isEmpty, "Período inválido no genera reporte")
let restoredReports = try JSONDecoder().decode(Ledger.self, from: JSONEncoder().encode(reports))
check(restoredReports.categories.map(\.colorIndex) == reports.categories.map(\.colorIndex), "Respaldo conserva colores de categorías")
check(Category.defaults.count == 52 && Set(Category.defaults.map(\.name)).count == 52, "Catálogo ampliado de 52 categorías sin nombres duplicados")
var legacyCatalog = Ledger()
legacyCatalog.categories = Array(legacyCatalog.categories.prefix(13))
legacyCatalog.categories.append(Category(name: " HERRAMIENTAS ", symbol: "hammer", section: "Mi sección"))
legacyCatalog.assignCategoryColors()
let originalCategories = legacyCatalog.categories
let categoryReference = legacyCatalog.categories[0].id
legacyCatalog.expenses = [Expense(title: "Existente", cents: 5000, firstMonth: november, walletID: legacyCatalog.wallets[0].id, categoryID: categoryReference)]
let expandedCount = legacyCatalog.addExpandedCategories()
legacyCatalog.assignCategoryColors()
check(expandedCount == Category.expanded.count - 1, "Expansión no duplica categoría del usuario con mayúsculas y espacios")
check(originalCategories.allSatisfy { original in legacyCatalog.categories.contains(original) }, "Expansión conserva nombres, secciones, íconos, IDs y colores existentes")
check(legacyCatalog.expenses[0].categoryID == categoryReference && legacyCatalog.expenses[0].cents == 5000, "Catálogo no reclasifica ni altera gastos")
let repeatExpansion = legacyCatalog.addExpandedCategories()
check(repeatExpansion == 0, "Expansión repetida no agrega duplicados")
check(["Herramientas", "Nafta", "Cochera", "Estacionamiento", "Mecánica", "Peajes"].allSatisfy { name in Category.defaults.contains { $0.name == name } }, "Incluye herramientas y categorías de auto solicitadas")
try legacyCatalog.validate()
try runOperationsChecks()
print("\(checks) verificaciones correctas; \(migration.count) cargos históricos validados.")
