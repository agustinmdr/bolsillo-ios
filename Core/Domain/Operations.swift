import Foundation

struct OperationsData: Codable {
    var rules: [MerchantRule] = []
    var statements: [StatementRecord] = []
    var adjustments: [StatementAdjustment] = []
    var closings: [CoupleClosing] = []
    var openings: [CoupleOpening] = []
    var migrationResolutions: [String: String] = [:]
    var completedMigrations: [String] = []
}
struct MerchantRule: Codable, Identifiable {
    var id = UUID()
    var text: String
    var categoryID: UUID
    var allocation: Allocation? = nil
    var maiPercent = 50
    var enabled = true
    func matches(_ expense: Expense) -> Bool {
        enabled && !normalized(text).isEmpty && normalized(expense.displayTitle).contains(normalized(text))
    }
}
func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_AR"))
}
struct BulkChange {
    var categoryID: UUID? = nil
    var allocation: Allocation? = nil
    var maiPercent = 50
    var markReviewed = true
}
struct BulkEdit { let before: Expense; let after: Expense }
struct BulkUndo { let edits: [BulkEdit] }
struct StatementRecord: Codable, Identifiable {
    var id = UUID()
    var walletID: UUID
    var month: Month
    var currency: String
    var reportedCents: Int64? = nil
    var paidCents: Int64 = 0
}
enum AdjustmentKind: String, Codable, CaseIterable, Identifiable {
    case fee = "Impuesto / cargo", interest = "Interés", refund = "Devolución / reintegro"
    var id: String { rawValue }
}
struct StatementAdjustment: Codable, Identifiable {
    var id = UUID()
    var walletID: UUID
    var month: Month
    var currency: String
    var title: String
    var cents: Int64
    var kind: AdjustmentKind
    var categoryID: UUID
    var allocation: Allocation = .mine
    var maiPercent = 50
    var paidBy: Person = .agus
    var signedCents: Int64 { kind == .refund ? -cents : cents }
    var charge: Charge {
        var e = Expense(title: title, cents: cents, currency: currency, date: month.date, firstMonth: month, walletID: walletID, categoryID: categoryID, allocation: allocation, maiPercent: maiPercent, paidBy: paidBy, tags: kind.rawValue, sourceKey: "statement-adjustment:" + id.uuidString)
        e.id = id
        return Charge(expense: e, month: month, cents: signedCents, number: 1)
    }
}
struct CoupleOpening: Codable, Identifiable {
    var id = UUID()
    var month: Month
    var currency: String
    /// Saldo previo al mes: positivo Mai debe a Agus.
    var cents: Int64
}
struct CoupleClosing: Codable, Identifiable {
    var id = UUID()
    var month: Month
    var currency: String
    var opening: Int64
    var movement: Int64
    var ending: Int64
    var date = Date()
    func matches(_ summary: CoupleSummary) -> Bool {
        opening == summary.opening && movement == summary.movement && ending == summary.ending
    }
}
struct CoupleSummary {
    let opening: Int64
    let movement: Int64
    var ending: Int64 { opening + movement }
}
struct MigrationCandidate: Codable, Identifiable {
    let id: String
    let month: Month
    let title: String
    let cents: Int64
    let currency: String
    /// income, fixed, expense, note, reference
    let kind: String
    let source: String
    let section: String
    let category: String?
    let paidBy: Person?
}
struct ScheduledCardReminder {
    let walletID: UUID
    let walletName: String
    let month: Month
    let fireDate: Date
    let dueDate: Date
    var id: String { "bolsillo.card.\(walletID).\(month.id)" }
}

extension Wallet {
    func closingDate(in month: Month) -> Date? {
        guard let closingDay else { return nil }
        return month.date(day: closingDay)
    }
    func dueDate(in month: Month) -> Date? {
        guard let dueDay else { return nil }
        return month.adding(dueMonthOffset ?? 1).date(day: dueDay)
    }
    func suggestedStatementMonth(for date: Date) -> Month {
        let month = Month(date)
        guard let closingDate = closingDate(in: month) else { return month }
        return Calendar.current.startOfDay(for: date) > closingDate ? month.adding(1) : month
    }
}
extension Month {
    func date(day: Int) -> Date {
        let days = Calendar.current.range(of: .day, in: .month, for: date)!.count
        return Calendar.current.date(byAdding: .day, value: min(max(day, 1), days)-1, to: date)!
    }
}
extension Expense {
    var needsReview: Bool {
        if let reviewed { return !reviewed }
        return sourceKey?.hasPrefix("planilla-") == true || sourceKey?.hasPrefix("apple-pay-") == true
    }
    var isAdjustment: Bool { sourceKey?.hasPrefix("statement-adjustment:") == true }
}
extension Ledger {
    var ops: OperationsData {
        get { operations ?? OperationsData() }
        set { operations = newValue }
    }
    func cardReminderPlan(now: Date = Date(), daysBefore: Int = 1, hour: Int = 10, minute: Int = 0) -> [ScheduledCardReminder] {
        guard (0...30).contains(daysBefore), (0...23).contains(hour), (0...59).contains(minute) else { return [] }
        let horizon = Calendar.current.date(byAdding: .month, value: 12, to: now)!
        var result: [ScheduledCardReminder] = []
        for wallet in creditCards where wallet.dueDay != nil {
            for offset in -2...12 {
                let month = Month(now).adding(offset)
                guard let due = wallet.dueDate(in: month) else { continue }
                let records = ops.statements.filter { $0.walletID == wallet.id && $0.month == month }
                let allPaid = ["ARS", "USD"].allSatisfy { currency in
                    if let record = records.first(where: { $0.currency == currency }), let total = record.reportedCents { return record.paidCents >= max(total, 0) && recordedStatement(walletID: wallet.id, month: month, currency: currency) == total }
                    return recordedStatement(walletID: wallet.id, month: month, currency: currency) <= 0
                }
                if !records.isEmpty && allPaid { continue }
                guard let fire = reminderDate(due: due, daysBefore: daysBefore, hour: hour, minute: minute), fire > now, fire <= horizon else { continue }
                result.append(ScheduledCardReminder(walletID: wallet.id, walletName: wallet.displayName, month: month, fireDate: fire, dueDate: due))
            }
        }
        return Array(result.sorted { $0.fireDate < $1.fireDate }.prefix(60))
    }
    mutating func applyBulk(ids: Set<UUID>, change: BulkChange) -> BulkUndo {
        var edits: [BulkEdit] = []
        for index in expenses.indices where ids.contains(expenses[index].id) {
            let before = expenses[index]
            if let categoryID = change.categoryID { expenses[index].categoryID = categoryID }
            if let allocation = change.allocation { expenses[index].allocation = allocation; expenses[index].maiPercent = change.maiPercent }
            if change.markReviewed { expenses[index].reviewed = true }
            if expenses[index] != before { edits.append(BulkEdit(before: before, after: expenses[index])) }
        }
        return BulkUndo(edits: edits)
    }
    @discardableResult mutating func undoBulk(_ undo: BulkUndo) -> Int {
        var restored = 0
        for edit in undo.edits {
            if let index = expenses.firstIndex(where: { $0.id == edit.after.id }), expenses[index] == edit.after {
                expenses[index] = edit.before; restored += 1
            }
        }
        return restored
    }
    func recordedStatement(walletID: UUID, month: Month, currency: String) -> Int64 {
        charges(in: month, currency: currency).filter { $0.expense.walletID == walletID }.reduce(0) { $0+$1.cents }
    }
    mutating func putStatement(_ record: StatementRecord) {
        ops.statements.removeAll { $0.walletID == record.walletID && $0.month == record.month && $0.currency == record.currency }
        ops.statements.append(record)
    }
    func coupleSummary(in month: Month, currency: String) -> CoupleSummary {
        let opening = ops.openings.filter { $0.currency == currency && $0.month <= month }.max { $0.month < $1.month }
        let starts = expenses.filter { $0.currency == currency }.map(\.firstMonth)
            + settlements.filter { $0.currency == currency }.map(\.month)
            + ops.adjustments.filter { $0.currency == currency }.map(\.month)
        let start = opening?.month ?? starts.min() ?? month
        var prior = opening?.cents ?? 0
        let distance = start.distance(to: month)
        if distance > 0 { for offset in 0..<distance { prior += balance(in: start.adding(offset), currency: currency) } }
        return CoupleSummary(opening: prior, movement: balance(in: month, currency: currency))
    }
    mutating func closeCoupleMonth(_ month: Month, currency: String) {
        let summary = coupleSummary(in: month, currency: currency)
        ops.closings.removeAll { $0.month == month && $0.currency == currency }
        ops.closings.append(CoupleClosing(month: month, currency: currency, opening: summary.opening, movement: summary.movement, ending: summary.ending))
    }
    func coupleText(in month: Month, currency: String) -> String {
        let summary = coupleSummary(in: month, currency: currency)
        let rows = charges(in: month, currency: currency)
        let detail = rows.filter { $0.balance != 0 || $0.expense.allocation == .shared }.map {
            "\($0.expense.displayTitle): \(money($0.cents, currency: currency)); pagó \($0.expense.paidBy.title); Mi parte \(money($0.agusShare, currency: currency)), Otra parte \(money($0.maiShare, currency: currency))"
        }.joined(separator: "\n")
        return "Bolsillo · \(month.label) · \(currency)\nSaldo anterior (positivo: me deben): \(money(summary.opening, currency: currency))\n\(detail)\nDevoluciones registradas: \(settlements.filter { $0.month == month && $0.currency == currency }.map { "\($0.from.title): \(money($0.cents, currency: currency))" }.joined(separator: ", "))\nSaldo final: \(summary.ending >= 0 ? "Me deben" : "Yo debo") \(money(abs(summary.ending), currency: currency))."
    }
    func matchingExpenses(for candidate: MigrationCandidate) -> [Expense] {
        let clean = normalized(ReportedInstallment.parse(candidate.title)?.cleanTitle ?? candidate.title)
        return expenses.filter { e in e.currency == candidate.currency && e.occurrence(in: candidate.month)?.cents == abs(candidate.cents) }.sorted { l, r in
            let lm = normalized(l.displayTitle) == clean
            let rm = normalized(r.displayTitle) == clean
            return lm && !rm
        }
    }
    private func hasPotentialFixedDuplicate(_ candidate: MigrationCandidate) -> Bool {
        let clean = normalized(ReportedInstallment.parse(candidate.title)?.cleanTitle ?? candidate.title)
        return matchingExpenses(for: candidate).contains { existing in
            // Dos filas inequívocas de la misma planilla pueden tener igual monto
            // y distinto concepto (por ejemplo cochera y seguro). No son duplicados.
            normalized(existing.displayTitle) == clean || existing.reviewed == true || existing.sourceKey?.hasPrefix("planilla-2026-") != true
        }
    }
    @discardableResult mutating func importSafeSupplement(_ candidates: [MigrationCandidate]) -> Int {
        var imported = 0
        for candidate in candidates where ops.migrationResolutions[candidate.id] == nil {
            if candidate.kind == "income", candidate.cents > 0 {
                if incomes.contains(where: { $0.sourceKey == candidate.id || ($0.month == candidate.month && $0.currency == candidate.currency && normalized($0.title) == normalized(candidate.title) && $0.cents == candidate.cents) }) {
                    ops.migrationResolutions[candidate.id] = "existing-income"; continue
                }
                if incomes.contains(where: { $0.month == candidate.month && $0.currency == candidate.currency && $0.cents == candidate.cents }) { continue }
                incomes.append(Income(month: candidate.month, title: candidate.title, cents: candidate.cents, currency: candidate.currency, sourceKey: candidate.id))
                ops.migrationResolutions[candidate.id] = "income"; imported += 1
            } else if candidate.kind == "fixed", candidate.cents > 0, !hasPotentialFixedDuplicate(candidate) {
                let wallet: Wallet
                if let existing = wallets.first(where: { $0.name == "Gastos fijos · planilla" }) { wallet = existing }
                else { wallet = Wallet(name: "Gastos fijos · planilla"); wallets.append(wallet) }
                guard let category = categories.first(where: { $0.name == candidate.category }) ?? categories.first(where: { $0.name == "Sin categorizar" }) else { continue }
                expenses.append(Expense(title: candidate.title, cents: candidate.cents, currency: candidate.currency, date: candidate.month.date, firstMonth: candidate.month, walletID: wallet.id, categoryID: category.id, notes: "Origen: \(candidate.source). Gasto mensual histórico; revisar responsable y medio de pago.", sourceKey: candidate.id))
                ops.migrationResolutions[candidate.id] = "expense"; imported += 1
            }
        }
        return imported
    }
    func validateOperations() throws {
        let o = ops
        func currency(_ c: String) -> Bool { ["ARS", "USD"].contains(c) }
        func month(_ m: Month) -> Bool { (1900...2300).contains(m.year) && (1...12).contains(m.month) }
        func wallet(_ id: UUID) -> Bool { wallets.contains { $0.id == id } }
        func category(_ id: UUID) -> Bool { categories.contains { $0.id == id } }
        func signedAmount(_ n: Int64) -> Bool { (-100_000_000_000...100_000_000_000).contains(n) }
        guard wallets.allSatisfy({ ($0.closingDay.map { (1...31).contains($0) } ?? true) && ($0.dueDay.map { (1...31).contains($0) } ?? true) && ($0.dueMonthOffset.map { (0...2).contains($0) } ?? true) }),
              o.rules.allSatisfy({ !normalized($0.text).isEmpty && category($0.categoryID) && (0...100).contains($0.maiPercent) }),
              o.statements.allSatisfy({ wallet($0.walletID) && month($0.month) && currency($0.currency) && ($0.reportedCents.map { signedAmount($0) } ?? true) && (0...100_000_000_000).contains($0.paidCents) }),
              o.adjustments.allSatisfy({ wallet($0.walletID) && category($0.categoryID) && month($0.month) && currency($0.currency) && (1...100_000_000_000).contains($0.cents) && (0...100).contains($0.maiPercent) && !normalized($0.title).isEmpty }),
              o.openings.allSatisfy({ month($0.month) && currency($0.currency) && signedAmount($0.cents) }),
              o.closings.allSatisfy({ month($0.month) && currency($0.currency) && signedAmount($0.opening) && signedAmount($0.movement) && signedAmount($0.ending) && $0.ending == $0.opening + $0.movement }),
              Set(o.adjustments.map(\.id)).count == o.adjustments.count,
              Set(o.adjustments.map(\.id)).isDisjoint(with: Set(expenses.map(\.id))),
              Set(o.rules.map(\.id)).count == o.rules.count,
              Set(o.statements.map { $0.walletID.uuidString + $0.month.id + $0.currency }).count == o.statements.count,
              Set(o.openings.map { $0.month.id + $0.currency }).count == o.openings.count,
              Set(o.closings.map { $0.month.id + $0.currency }).count == o.closings.count else { throw FinanceError.invalid }
    }
}
func parseSignedCents(_ text: String) -> Int64? {
    let clean = text.trimmingCharacters(in: .whitespaces)
    if ["0", "0,00", "0,0"].contains(clean) { return 0 }
    if clean.hasPrefix("-") { return parseCents(String(clean.dropFirst())).map { -$0 } }
    return parseCents(clean)
}
func editableAmount(_ cents: Int64) -> String { String(format: "%.2f", Double(cents)/100).replacingOccurrences(of: ".", with: ",") }

extension Ledger {
    @discardableResult mutating func cleanImportedWallets() -> Bool {
        let marker = "wallets-cleanup-2026-v1"
        guard !ops.completedMigrations.contains(marker) else { return false }
        for i in wallets.indices {
            if wallets[i].name == "GALICIA MASTERCARD" { wallets[i].archived = true }
            if wallets[i].name == "Gastos fijos · planilla" {
                wallets[i].name = "Gastos fijos"
                wallets[i].creditCard = false
            }
        }
        ops.completedMigrations.append(marker)
        return true
    }
    /// Aplica una configuración explícita del usuario, sin incluir importes privados en el código.
    @discardableResult mutating func applyConfirmedSetup(_ setup: ConfirmedLedgerSetup) -> Bool {
        guard !ops.completedMigrations.contains(setup.id) else { return false }
        let sources = Set(setup.sourceKeys)
        for i in expenses.indices where expenses[i].firstMonth == setup.statementMonth && expenses[i].currency == setup.currency && sources.contains(expenses[i].sourceKey ?? "") && expenses[i].purchaseMonth == nil {
            expenses[i].purchaseMonth = setup.purchaseMonth
        }
        let fallbackWallet: UUID
        if let wallet = wallets.first(where: { ["Gastos fijos · planilla", "Gastos fijos"].contains($0.name) }) ?? wallets.first { fallbackWallet = wallet.id }
        else { let wallet = Wallet(name: "Gastos fijos", creditCard: false); wallets.append(wallet); fallbackWallet = wallet.id }
        for fixed in setup.fixed {
            let categoryID: UUID
            if let category = categories.first(where: { normalized($0.name) == normalized(fixed.title) }) { categoryID = category.id }
            else { let category = Category(name: fixed.title, symbol: fixed.symbol, section: fixed.section); categories.append(category); categoryID = category.id }
            let existing = expenses.firstIndex(where: { $0.sourceKey == fixed.sourceKey }) ?? expenses.firstIndex(where: { $0.firstMonth == setup.statementMonth && $0.currency == setup.currency && normalized($0.title) == normalized(fixed.title) && $0.cents == fixed.cents })
            if let i = existing {
                if expenses[i].firstMonth == setup.statementMonth && expenses[i].installments == 1 {
                    expenses[i].cents = fixed.cents; expenses[i].categoryID = categoryID
                    expenses[i].recurring = true; expenses[i].endMonth = nil
                    if fixed.personalContribution { expenses[i].allocation = .mine }
                    expenses[i].reviewed = true
                }
                ops.migrationResolutions[fixed.sourceKey] = "linked:\(expenses[i].id)"
            } else {
                let walletID = fixed.personalContribution ? (wallets.first { $0.name == "Efectivo / transferencia" }?.id ?? fallbackWallet) : fallbackWallet
                var expense = Expense(title: fixed.title, cents: fixed.cents, currency: setup.currency, date: setup.statementMonth.date, firstMonth: setup.statementMonth, recurring: true, walletID: walletID, categoryID: categoryID, notes: "Gasto fijo mensual confirmado por el usuario.", sourceKey: fixed.sourceKey, reviewed: true)
                if fixed.personalContribution { expense.notes += " Es mi aporte personal, no el total a dividir entre personas." }
                expenses.append(expense); ops.migrationResolutions[fixed.sourceKey] = "expense"
            }
        }
        assignCategoryColors()
        ops.completedMigrations.append(setup.id)
        return true
    }
}

/// Configuración opcional cargada desde un recurso local excluido del repositorio.
struct ConfirmedLedgerSetup: Codable {
    var id: String
    var purchaseMonth: Month
    var statementMonth: Month
    var currency: String
    var sourceKeys: [String]
    var fixed: [Fixed]
    struct Fixed: Codable {
        var title: String
        var cents: Int64
        var section: String
        var symbol: String
        var sourceKey: String
        var personalContribution: Bool
    }
}
