import Foundation

func runOperationsChecks() throws {
    let jan = Month(year: 2026, month: 1)
    let feb = jan.adding(1)
    var ledger = Ledger()
    let wallet = ledger.wallets[0].id
    let category = ledger.categories[0].id
    let otherCategory = ledger.categories[1].id
    var original = Expense(title: "SHELL nafta", cents: 10001, firstMonth: jan, installments: 3, walletID: wallet, categoryID: category, sourceKey: "planilla-2026-example")
    let other = Expense(title: "Otro", cents: 2000, firstMonth: jan, walletID: wallet, categoryID: category)
    ledger.expenses = [original, other]
    check(original.needsReview && !other.needsReview, "Pendientes derivados de importación, no de gastos manuales")
    let undo = ledger.applyBulk(ids: [original.id], change: BulkChange(categoryID: otherCategory, allocation: .shared, maiPercent: 35))
    check(ledger.expenses[0].categoryID == otherCategory && ledger.expenses[0].allocation == .shared && ledger.expenses[0].maiPercent == 35 && !ledger.expenses[0].needsReview, "Lote aplica categoría, reparto y revisión")
    check(ledger.expenses[0].cents == original.cents && ledger.expenses[0].firstMonth == original.firstMonth && ledger.expenses[0].installments == original.installments && ledger.expenses[1] == other, "Lote conserva montos, serie y gastos no seleccionados")
    let newlyCaptured = Expense(title: "Nuevo", cents: 500, firstMonth: feb, walletID: wallet, categoryID: category)
    ledger.expenses.append(newlyCaptured)
    check(ledger.undoBulk(undo) == 1 && ledger.expenses[0] == original && ledger.expenses.contains(newlyCaptured), "Deshacer conserva gastos añadidos después")
    let secondUndo = ledger.applyBulk(ids: [original.id], change: BulkChange(categoryID: otherCategory))
    ledger.expenses[0].title = "Editado después"
    check(ledger.undoBulk(secondUndo) == 0 && ledger.expenses[0].title == "Editado después", "Deshacer no pisa ediciones posteriores")
    var rule = MerchantRule(text: " shÉll ", categoryID: otherCategory)
    check(rule.matches(original), "Regla normaliza espacios, mayúsculas y acentos")
    rule.enabled = false
    check(!rule.matches(original), "Regla deshabilitada no coincide")
    rule.enabled = true; rule.text = " .* "
    check(!rule.matches(original), "Regla usa texto literal y no ejecuta expresiones regulares")

    var card = Wallet(name: "Prueba", closingDay: 20, dueDay: 5, dueMonthOffset: 1)
    check(card.suggestedStatementMonth(for: jan.date(day: 20)) == jan, "Día exacto de cierre entra en ese resumen")
    check(card.suggestedStatementMonth(for: jan.date(day: 21)) == feb, "Día posterior al cierre entra en mes siguiente")
    check(card.dueDate(in: jan) == feb.date(day: 5), "Vencimiento en mes siguiente")
    card.closingDay = 31
    check(card.closingDate(in: feb) == feb.date(day: 28), "Cierre 31 se ajusta a febrero no bisiesto")
    let leap = Month(year: 2028, month: 2)
    check(card.closingDate(in: leap) == leap.date(day: 29), "Cierre contempla febrero bisiesto")
    card.dueDay = 31
    check(card.dueDate(in: jan) == feb.date(day: 28), "Vencimiento 31 también se ajusta")
    card.closingDay = nil
    check(card.suggestedStatementMonth(for: jan.date(day: 30)) == jan, "Sin cierre no inventa desplazamiento")
    var captureLedger = Ledger()
    captureLedger.wallets[0].closingDay = 20
    let capture = WalletCapture(amount: 50, merchant: "Pago", currency: "ARS", walletID: captureLedger.wallets[0].id, date: jan.date(day: 21))
    _ = try capture.apply(to: &captureLedger)
    check(captureLedger.expenses[0].firstMonth == feb, "Wallet usa cierre configurado cuando no se pasa mes explícito")

    var reconciliation = Ledger()
    original.installments = 1; original.cents = 10000; original.allocation = .shared
    reconciliation.expenses = [original]
    let fee = StatementAdjustment(walletID: wallet, month: jan, currency: "ARS", title: "Impuesto", cents: 200, kind: .fee, categoryID: category)
    let refund = StatementAdjustment(walletID: wallet, month: jan, currency: "ARS", title: "Reintegro", cents: 99, kind: .refund, categoryID: category, allocation: .shared)
    // Se reutilizan las referencias originales; identidades de categorías/cuentas
    // se preservan como ocurre en un respaldo real.
    reconciliation.wallets = ledger.wallets; reconciliation.categories = ledger.categories
    reconciliation.ops.adjustments = [fee, refund]
    check(reconciliation.recordedStatement(walletID: wallet, month: jan, currency: "ARS") == 10101, "Conciliación suma cargos e impuestos y descuenta reintegros")
    check(refund.charge.maiShare == -50 && refund.charge.agusShare == -49 && refund.charge.balance == -50, "Reintegro compartido conserva signo y centavos")
    check(reconciliation.balance(in: jan, currency: "ARS") == 4950, "Reintegro reduce la deuda con Mai")
    check(reconciliation.monthlySpending(endingAt: jan, count: 1, currency: "ARS", portion: .total).reduce(0) { $0+$1.cents } == 10101, "Reporte usa ajustes netos sin duplicación")
    let beforePayment = reconciliation.expenses
    reconciliation.putStatement(StatementRecord(walletID: wallet, month: jan, currency: "ARS", reportedCents: 10101, paidCents: 3000))
    reconciliation.putStatement(StatementRecord(walletID: wallet, month: jan, currency: "ARS", reportedCents: 10101, paidCents: 7000))
    check(reconciliation.ops.statements.count == 1 && reconciliation.ops.statements[0].paidCents == 7000, "Pago es acumulado y actualizar no duplica resumen")
    check(reconciliation.expenses == beforePayment && reconciliation.balance(in: jan, currency: "ARS") == 4950, "Pagar banco no crea otro gasto ni liquida deuda con pareja")
    try reconciliation.validate()
    var allRefund = reconciliation
    allRefund.expenses = []; allRefund.ops.adjustments = [refund]
    check(allRefund.monthlySpending(endingAt: jan, count: 1, currency: "ARS", portion: .total).reduce(0) { $0+$1.cents } == -99, "Mes con solo devoluciones conserva gasto neto negativo")
    check(parseSignedCents("-1.234,56") == -123456 && parseSignedCents("0") == 0 && parseSignedCents("abc") == nil, "Resumen admite saldo a favor y cero sin ocultar entradas inválidas")

    var couple = Ledger(); couple.wallets = ledger.wallets; couple.categories = ledger.categories
    couple.expenses = [Expense(title: "Compartido", cents: 10000, firstMonth: jan, walletID: wallet, categoryID: category, allocation: .shared), Expense(title: "Mai pagó mío", cents: 4000, firstMonth: feb, walletID: wallet, categoryID: category, paidBy: .mai)]
    couple.settlements = [Settlement(month: jan, from: .mai, cents: 2000, currency: "ARS")]
    couple.ops.adjustments = [StatementAdjustment(walletID: wallet, month: feb, currency: "ARS", title: "Devolución compartida", cents: 2000, kind: .refund, categoryID: category, allocation: .shared)]
    let febSummary = couple.coupleSummary(in: feb, currency: "ARS")
    check(febSummary.opening == 3000 && febSummary.movement == -5000 && febSummary.ending == -2000, "Liquidación arrastra deuda y descuenta pagos y reintegros")
    couple.closeCoupleMonth(feb, currency: "ARS"); couple.closeCoupleMonth(feb, currency: "ARS")
    check(couple.ops.closings.count == 1 && couple.ops.closings[0].matches(febSummary), "Cierre repetido actualiza una foto, no suma otra deuda")
    check(couple.coupleSummary(in: feb.adding(1), currency: "ARS").opening == -2000, "Mes siguiente arrastra una sola vez")
    couple.expenses[0].cents = 8000
    check(!couple.ops.closings[0].matches(couple.coupleSummary(in: feb, currency: "ARS")), "Cambio posterior marca cierre desactualizado")
    couple.ops.openings = [CoupleOpening(month: feb, currency: "ARS", cents: 9000)]
    check(couple.coupleSummary(in: feb, currency: "ARS").ending == 4000, "Saldo inicial reemplaza, no suma, historia previa")
    check(couple.coupleSummary(in: feb, currency: "USD").ending == 0, "Saldo de pareja no mezcla monedas")
    try couple.validate()

    var clean = Ledger()
    let originalWalletIDs = clean.wallets.map(\.id)
    check(clean.cleanImportedWallets(), "Aplica limpieza de cuentas")
    check(clean.creditCards.count == 2 && clean.wallets.map(\.id) == originalWalletIDs, "Archivar preserva referencias")
    check(!clean.cleanImportedWallets(), "No repite limpieza")
    let setup = ConfirmedLedgerSetup(id: "synthetic-setup-v1", purchaseMonth: jan, statementMonth: feb, currency: "ARS", sourceKeys: ["sample-purchase"], fixed: [.init(title: "Servicio de ejemplo", cents: 12345, section: "Casa", symbol: "house", sourceKey: "sample-fixed", personalContribution: true)])
    clean.expenses = [Expense(title: "Compra", cents: 5000, firstMonth: feb, walletID: clean.wallets[0].id, categoryID: clean.categories[0].id, sourceKey: "sample-purchase")]
    let purchaseID = clean.expenses[0].id
    check(clean.applyConfirmedSetup(setup), "Aplica configuración genérica local")
    check(clean.expenses.count == 2 && clean.expenses[0].id == purchaseID && clean.expenses[0].purchaseMonth == jan, "Conserva compra y separa consumo del resumen")
    let fixed = clean.expenses.first { $0.sourceKey == "sample-fixed" }!
    check(fixed.recurring && fixed.allocation == .mine && fixed.occurrence(in: feb.adding(1))?.cents == 12345 && fixed.occurrence(in: jan) == nil, "Aporte personal recurrente sin doble reparto")
    check(!clean.applyConfirmedSetup(setup) && clean.expenses.count == 2, "Configuración idempotente")
    try clean.validate()
    let restored = try JSONDecoder().decode(Ledger.self, from: LedgerStorage.data(clean))
    check(restored.creditCards.count == 2 && restored.expenses == clean.expenses, "Respaldo conserva archivo, consumo y recurrencias")

    let supplemented = clean
    var notifications = Ledger()
    notifications.wallets[0].closingDay = 20; notifications.wallets[0].dueDay = 5; notifications.wallets[0].dueMonthOffset = 1
    let noticeWallet = notifications.wallets[0].id
    notifications.expenses = [Expense(title: "Cargo", cents: 1000, firstMonth: jan, walletID: noticeWallet, categoryID: notifications.categories[0].id)]
    let plan = notifications.cardReminderPlan(now: jan.date(day: 1))
    let januaryNotice = plan.first { $0.month == jan }!
    check(Calendar.current.component(.day, from: januaryNotice.fireDate) == 4 && Calendar.current.component(.hour, from: januaryNotice.fireDate) == 10 && Month(januaryNotice.fireDate) == feb, "Aviso se programa a las 10 del día anterior al vencimiento")
    check(Set(plan.map(\.id)).count == plan.count && plan.allSatisfy { $0.fireDate > jan.date(day: 1) }, "Recordatorios tienen IDs estables y no incluyen fechas pasadas")
    notifications.putStatement(StatementRecord(walletID: noticeWallet, month: jan, currency: "ARS", reportedCents: 1000, paidCents: 1000))
    check(!notifications.cardReminderPlan(now: jan.date(day: 1)).contains { $0.month == jan }, "Resumen conciliado y pagado no genera aviso")
    notifications.expenses.append(Expense(title: "USD sin pagar", cents: 100, currency: "USD", firstMonth: jan, walletID: noticeWallet, categoryID: notifications.categories[0].id))
    check(notifications.cardReminderPlan(now: jan.date(day: 1)).contains { $0.month == jan }, "Pago en ARS no oculta vencimiento con USD pendientes")
    let decodedOld = try JSONDecoder().decode(Ledger.self, from: JSONSerialization.data(withJSONObject: {
        var object = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as! [String: Any]
        object.removeValue(forKey: "operations"); return object
    }()))
    check(decodedOld.ops.adjustments.isEmpty && decodedOld.ops.rules.isEmpty, "Respaldos previos a operaciones siguen siendo válidos")
    try decodedOld.validate()

    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BolsilloTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let storage = LedgerStorage(folder: folder)
    check(try storage.load() == nil, "Archivo inexistente se distingue de archivo corrupto")
    _ = try storage.save(supplemented)
    let loaded = try storage.load()!
    check(loaded.incomes.isEmpty && loaded.expenses.count == 2, "Persistencia conserva migración e ingresos")
    let firstBackups = try LedgerStorage.snapshots(in: storage.backupsURL)
    check(firstBackups.count == 1, "Primer guardado tiene respaldo válido")
    _ = try storage.save(supplemented)
    check(try LedgerStorage.snapshots(in: storage.backupsURL).count == 1, "No duplica respaldo cuando no cambian datos")
    var next = supplemented; next.expenses[0].title = "Cambio protegido"
    _ = try storage.save(next)
    let backups = try LedgerStorage.snapshots(in: storage.backupsURL)
    let previousBackup = try storage.decode(Data(contentsOf: backups.last!))
    check(backups.count == 2 && previousBackup.expenses[0].title == supplemented.expenses[0].title, "Guardado conserva versión anterior restaurable")
    let bytes = try Data(contentsOf: storage.fileURL)
    var invalid = next; invalid.expenses[0].categoryID = UUID()
    do { _ = try storage.save(invalid); fatalError("Guardó un ledger inválido") } catch { checks += 1 }
    check(try Data(contentsOf: storage.fileURL) == bytes, "Fallo de validación no altera archivo actual")
    try Data("archivo corrupto".utf8).write(to: storage.fileURL)
    do { _ = try storage.load(); fatalError("Leyó datos corruptos como vacíos") } catch { checks += 1 }
    do { _ = try storage.save(next); fatalError("Sobrescribió archivo corrupto sin restauración") } catch { checks += 1 }
    _ = try storage.save(supplemented, restoring: true)
    check(try storage.load()!.expenses.count == 2, "Restauración explícita recupera datos válidos")
    check(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.hasPrefix("Recovery-") }, "Restauración conserva bytes corruptos para recuperación")
    let rotationFolder = folder.appendingPathComponent("Rotación", isDirectory: true)
    try FileManager.default.createDirectory(at: rotationFolder, withIntermediateDirectories: true)
    let unrelated = rotationFolder.appendingPathComponent("Bolsillo-respaldo.json")
    try Data("no borrar".utf8).write(to: unrelated)
    for index in 0..<5 {
        next.expenses[0].title = "Versión \(index)"
        _ = try LedgerStorage.snapshot(LedgerStorage.data(next), in: rotationFolder, retention: 3)
    }
    let retained = try LedgerStorage.snapshots(in: rotationFolder)
    check(retained.count == 3, "Rotación respeta límite de versiones")
    check(FileManager.default.fileExists(atPath: unrelated.path), "Rotación no elimina archivos ajenos al formato de respaldos")
    check(try retained.allSatisfy { _ = try storage.decode(Data(contentsOf: $0)); return true }, "Todas las versiones retenidas son restaurables")
    let blocked = LedgerStorage(folder: folder.appendingPathComponent("Blocked"))
    try FileManager.default.createDirectory(at: blocked.folder, withIntermediateDirectories: true)
    let protectedBytes = try LedgerStorage.data(supplemented)
    try protectedBytes.write(to: blocked.fileURL)
    try Data("obstrucción".utf8).write(to: blocked.backupsURL)
    do { _ = try blocked.save(next, restoring: true); fatalError("Sobrescribió datos aunque falló la protección anterior") } catch { checks += 1 }
    check(try Data(contentsOf: blocked.fileURL) == protectedBytes, "Incluso restaurando, fallo del respaldo previo deja datos intactos")
}
