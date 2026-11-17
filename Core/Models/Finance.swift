import Foundation

enum Person: String, Codable, CaseIterable, Identifiable {
    case agus = "Agustín", mai = "Mai"
    var title: String { self == .agus ? "Yo" : "Otra persona" }
    var id: String { rawValue }
}
enum Allocation: String, Codable, CaseIterable, Identifiable {
    case mine = "Mío", mai = "De Mai", shared = "Compartido"
    // Los valores almacenados se conservan para leer respaldos y CSV históricos.
    var title: String { switch self { case .mine: "Mío"; case .mai: "De otra persona"; case .shared: "Compartido" } }
    var symbol: String { switch self { case .mine: "person.fill"; case .mai: "person.crop.square"; case .shared: "person.2.fill" } }
    var id: String { rawValue }
}
struct Month: Codable, Hashable, Comparable, Identifiable {
    var year: Int
    var month: Int
    var id: String { String(format: "%04d-%02d", year, month) }
    init(_ date: Date = Date()) {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        year = c.year!; month = c.month!
    }
    init(year: Int, month: Int) { self.year = year; self.month = month }
    var date: Date { Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))! }
    var label: String { date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "es_AR"))) }
    func adding(_ n: Int) -> Month { Month(Calendar.current.date(byAdding: .month, value: n, to: date)!) }
    func distance(to other: Month) -> Int { (other.year-year)*12 + other.month-month }
    static func < (lhs: Month, rhs: Month) -> Bool { lhs.id < rhs.id }
}
struct Wallet: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var owner: Person = .agus
    var isExtension = false
    var closingDay: Int? = nil
    var dueDay: Int? = nil
    var dueMonthOffset: Int? = nil
    var archived: Bool? = nil
    var creditCard: Bool? = nil
    var isArchived: Bool { archived == true }
    var isCreditCard: Bool { creditCard ?? !["Efectivo / transferencia", "Pagado por Mai", "Gastos fijos · planilla", "Gastos fijos"].contains(name) }
}
struct Category: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var section: String
    var colorIndex: Int? = nil
    static let defaults: [Category] = [
        .init(name: "Tecnología", symbol: "laptopcomputer", section: "Personal"),
        .init(name: "Supermercado", symbol: "basket.fill", section: "Día a día"),
        .init(name: "Auto", symbol: "car.fill", section: "Día a día"),
        .init(name: "Comidas", symbol: "fork.knife", section: "Día a día"),
        .init(name: "Transporte", symbol: "car.fill", section: "Día a día"),
        .init(name: "Hogar", symbol: "house.fill", section: "Casa"),
        .init(name: "Servicios", symbol: "bolt.fill", section: "Casa"),
        .init(name: "Salud", symbol: "cross.case.fill", section: "Personal"),
        .init(name: "Compras", symbol: "bag.fill", section: "Personal"),
        .init(name: "Suscripciones", symbol: "repeat", section: "Personal"),
        .init(name: "Mascotas", symbol: "pawprint.fill", section: "Casa"),
        .init(name: "Ocio", symbol: "sparkles", section: "Personal"),
        .init(name: "Sin categorizar", symbol: "square.grid.2x2.fill", section: "Otros")] + expanded
    static let expanded: [Category] = [
        .init(name: "Nafta", symbol: "fuelpump.fill", section: "Auto"),
        .init(name: "Cochera", symbol: "parkingsign.circle.fill", section: "Auto"),
        .init(name: "Estacionamiento", symbol: "parkingsign", section: "Auto"),
        .init(name: "Peajes", symbol: "road.lanes", section: "Auto"),
        .init(name: "Mecánica", symbol: "wrench.and.screwdriver.fill", section: "Auto"),
        .init(name: "Seguro auto", symbol: "shield.lefthalf.filled", section: "Auto"),
        .init(name: "Lavado auto", symbol: "drop.fill", section: "Auto"),
        .init(name: "Repuestos", symbol: "gearshape.fill", section: "Auto"),
        .init(name: "Herramientas", symbol: "hammer.fill", section: "Casa"),
        .init(name: "Ferretería", symbol: "wrench.fill", section: "Casa"),
        .init(name: "Alquiler", symbol: "key.fill", section: "Casa"),
        .init(name: "Expensas", symbol: "building.2.fill", section: "Casa"),
        .init(name: "Muebles", symbol: "sofa.fill", section: "Casa"),
        .init(name: "Decoración", symbol: "lamp.table.fill", section: "Casa"),
        .init(name: "Limpieza", symbol: "bubbles.and.sparkles.fill", section: "Casa"),
        .init(name: "Reparaciones", symbol: "wrench.and.screwdriver.fill", section: "Casa"),
        .init(name: "Jardín", symbol: "leaf.fill", section: "Casa"),
        .init(name: "Mudanza", symbol: "shippingbox.fill", section: "Casa"),
        .init(name: "Delivery", symbol: "bicycle", section: "Día a día"),
        .init(name: "Café", symbol: "cup.and.saucer.fill", section: "Día a día"),
        .init(name: "Kiosco", symbol: "storefront.fill", section: "Día a día"),
        .init(name: "Taxi / Uber", symbol: "car.side.fill", section: "Día a día"),
        .init(name: "Ropa", symbol: "tshirt.fill", section: "Personal"),
        .init(name: "Calzado", symbol: "shoe.fill", section: "Personal"),
        .init(name: "Cuidado personal", symbol: "sparkles", section: "Personal"),
        .init(name: "Farmacia", symbol: "pills.fill", section: "Personal"),
        .init(name: "Terapia", symbol: "brain.head.profile", section: "Personal"),
        .init(name: "Gimnasio", symbol: "dumbbell.fill", section: "Personal"),
        .init(name: "Deportes", symbol: "figure.run", section: "Personal"),
        .init(name: "Educación", symbol: "graduationcap.fill", section: "Personal"),
        .init(name: "Regalos", symbol: "gift.fill", section: "Personal"),
        .init(name: "Viajes", symbol: "airplane", section: "Personal"),
        .init(name: "Alojamiento", symbol: "bed.double.fill", section: "Personal"),
        .init(name: "Cine y teatro", symbol: "theatermasks.fill", section: "Personal"),
        .init(name: "Videojuegos", symbol: "gamecontroller.fill", section: "Personal"),
        .init(name: "Bancos", symbol: "building.columns.fill", section: "Otros"),
        .init(name: "Impuestos", symbol: "doc.text.fill", section: "Otros"),
        .init(name: "Veterinaria", symbol: "cross.case.fill", section: "Mascotas"),
        .init(name: "Alimento mascota", symbol: "pawprint.fill", section: "Mascotas")]
}
struct ReportedInstallment: Codable, Equatable {
    var number: Int
    var total: Int
    var isValid: Bool { total > 1 && total <= 120 && (1...total).contains(number) }
    static func parse(_ title: String) -> (info: ReportedInstallment, cleanTitle: String)? {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\S)(\d{1,3})/(\d{1,3})(?!\S)"#),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let first = Range(match.range(at: 1), in: title), let last = Range(match.range(at: 2), in: title),
              let token = Range(match.range, in: title), let number = Int(title[first]), let total = Int(title[last]) else { return nil }
        let info = ReportedInstallment(number: number, total: total)
        let clean = title.replacingCharacters(in: token, with: "").replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return info.isValid && !clean.isEmpty ? (info, clean) : nil
    }
}
struct InstallmentProgress {
    let number: Int
    let total: Int
    let lastMonth: Month
    let historical: Bool
    var remaining: Int { total - number }
    var fraction: Double { Double(number) / Double(total) }
    var label: String { "Cuota \(number) de \(total)" }
}
struct Expense: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    /// Total de la compra, en centavos. Las cuotas distribuyen el resto sin perder centavos.
    var cents: Int64
    var currency = "ARS"
    var date = Date()
    var firstMonth: Month
    var installments = 1
    var recurring = false
    var endMonth: Month? = nil
    var walletID: UUID
    var categoryID: UUID
    var allocation: Allocation = .mine
    var maiPercent = 50
    var paidBy: Person = .agus
    var notes = ""
    var tags = ""
    var sourceKey: String? = nil
    var reportedInstallment: ReportedInstallment? = nil
    var originalTitle: String? = nil
    var reviewed: Bool? = nil
    /// Mes de consumo confirmado cuando no se conoce el día exacto.
    var purchaseMonth: Month? = nil
    /// Número de la primera cuota registrada; nil conserva los planes anteriores desde 1.
    var firstInstallment: Int? = nil
    var firstInstallmentNumber: Int { firstInstallment ?? 1 }
    var historicalInstallment: ReportedInstallment? {
        guard installments == 1, !recurring, sourceKey?.hasPrefix("planilla-2026-") == true else { return nil }
        return reportedInstallment ?? ReportedInstallment.parse(title)?.info
    }
    var displayTitle: String {
        guard historicalInstallment != nil else { return title }
        return ReportedInstallment.parse(title)?.cleanTitle ?? title
    }
    func occurrence(in month: Month) -> Charge? {
        let index = firstMonth.distance(to: month)
        guard index >= 0 else { return nil }
        if recurring {
            guard endMonth == nil || month <= endMonth! else { return nil }
            return Charge(expense: self, month: month, cents: cents, number: index+1)
        }
        let first = firstInstallmentNumber
        guard installments > 0, first >= 1, first <= installments, index < installments-first+1 else { return nil }
        let count = Int64(installments)
        let number = first+index
        return Charge(expense: self, month: month, cents: cents/count + (Int64(number-1) < cents%count ? 1 : 0), number: number)
    }
}
struct Charge: Identifiable {
    let expense: Expense
    let month: Month
    let cents: Int64
    let number: Int
    var id: String { expense.id.uuidString + month.id }
    var installmentProgress: InstallmentProgress? {
        if !expense.recurring && expense.installments > 1 {
            return InstallmentProgress(number: number, total: expense.installments, lastMonth: expense.firstMonth.adding(expense.installments-expense.firstInstallmentNumber), historical: false)
        }
        if let report = expense.historicalInstallment, report.isValid {
            return InstallmentProgress(number: report.number, total: report.total, lastMonth: month.adding(report.total-report.number), historical: true)
        }
        return nil
    }
    var maiShare: Int64 {
        switch expense.allocation {
        case .mine: return 0
        case .mai: return cents
        case .shared: return cents >= 0 ? (cents * Int64(expense.maiPercent) + 50) / 100 : -(((-cents) * Int64(expense.maiPercent) + 50) / 100)
        }
    }
    var agusShare: Int64 { cents - maiShare }
    /// Positivo: Mai debe a Agustín. Negativo: Agustín debe a Mai.
    var balance: Int64 { expense.paidBy == .agus ? maiShare : -agusShare }
}
struct Settlement: Codable, Identifiable {
    var id = UUID()
    var month: Month
    var from: Person
    var cents: Int64
    var currency: String
    var date = Date()
}
struct Income: Codable, Identifiable {
    var id = UUID()
    var month: Month
    var title: String
    var cents: Int64
    var currency = "ARS"
    var sourceKey: String? = nil
}
struct Budget: Codable, Identifiable {
    var id = UUID()
    var categoryID: UUID
    var cents: Int64
    var currency = "ARS"
}
struct Ledger: Codable {
    var version = 1
    var expenses: [Expense] = []
    var wallets: [Wallet] = [
        .init(name: "ICBC VISA"), .init(name: "ICBC MASTERCARD"),
        .init(name: "GALICIA MASTERCARD", isExtension: true),
        .init(name: "Efectivo / transferencia"), .init(name: "Pagado por Mai", owner: .mai)]
    var categories = Category.defaults
    var budgets: [Budget] = []
    var incomes: [Income] = []
    var settlements: [Settlement] = []
    var operations: OperationsData? = nil
    var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }
    var creditCards: [Wallet] { activeWallets.filter(\.isCreditCard) }
    @discardableResult mutating func addExpandedCategories() -> Int {
        func key(_ name: String) -> String {
            name.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_AR"))
        }
        let existing = Set(categories.map { key($0.name) })
        let additions = Category.expanded.filter { !existing.contains(key($0.name)) }
        categories.append(contentsOf: additions)
        return additions.count
    }
    @discardableResult mutating func assignCategoryColors() -> Bool {
        var changed = false
        var used = Set(categories.compactMap(\.colorIndex))
        for index in categories.indices where categories[index].colorIndex == nil {
            var color = 0
            while used.contains(color) { color += 1 }
            categories[index].colorIndex = color; used.insert(color); changed = true
        }
        return changed
    }
    func monthlySpending(endingAt end: Month, count: Int, currency: String, portion: SpendingPortion) -> [MonthlyCategoryAmount] {
        guard (1...12).contains(count) else { return [] }
        return (0..<count).flatMap { offset -> [MonthlyCategoryAmount] in
            let month = end.adding(offset-count+1)
            let charges = charges(in: month, currency: currency)
            return categories.map { category in
                let amount = charges.filter { $0.expense.categoryID == category.id }.reduce(Int64(0)) { sum, charge in
                    switch portion {
                    case .total: return sum + charge.cents
                    case .mine: return sum + charge.agusShare
                    case .mai: return sum + charge.maiShare
                    }
                }
                return MonthlyCategoryAmount(month: month, categoryID: category.id, cents: amount)
            }
        }
    }
    func charges(in month: Month, currency: String) -> [Charge] {
        expenses.filter { $0.currency == currency }.compactMap { $0.occurrence(in: month) }
            + ops.adjustments.filter { $0.currency == currency && $0.month == month }.map(\.charge)
    }
    func balance(in month: Month, currency: String) -> Int64 {
        charges(in: month, currency: currency).reduce(0) { $0 + $1.balance } - settlements.filter { $0.month == month && $0.currency == currency }.reduce(0) { $0 + ($1.from == .mai ? $1.cents : -$1.cents) }
    }
    func validate() throws {
        try validateOperations()
        func validMonth(_ m: Month) -> Bool { (1900...2300).contains(m.year) && (1...12).contains(m.month) }
        func validAmount(_ cents: Int64, _ currency: String) -> Bool { cents > 0 && cents <= 100_000_000_000 && ["ARS", "USD"].contains(currency) }
        guard version == 1, !wallets.isEmpty, !categories.isEmpty,
              Set(wallets.map(\.id)).count == wallets.count,
              Set(categories.map(\.id)).count == categories.count,
              Set(expenses.map(\.id)).count == expenses.count,
              Set(incomes.map(\.id)).count == incomes.count,
              Set(settlements.map(\.id)).count == settlements.count,
              Set(budgets.map(\.id)).count == budgets.count,
              expenses.allSatisfy({ e in validAmount(e.cents, e.currency) && (1...120).contains(e.installments) && (0...100).contains(e.maiPercent) && wallets.contains(where: { $0.id == e.walletID }) && categories.contains(where: { $0.id == e.categoryID }) && validMonth(e.firstMonth) && (e.endMonth.map { validMonth($0) && $0 >= e.firstMonth } ?? true) && (e.reportedInstallment?.isValid ?? true) }),
              settlements.allSatisfy({ validAmount($0.cents, $0.currency) && validMonth($0.month) }),
              incomes.allSatisfy({ validAmount($0.cents, $0.currency) && validMonth($0.month) }),
              budgets.allSatisfy({ b in validAmount(b.cents, b.currency) && categories.contains { $0.id == b.categoryID } }),
              wallets.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }),
              categories.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && !$0.section.isEmpty && ($0.colorIndex.map { (0...10000).contains($0) } ?? true) }) else { throw FinanceError.invalid }
        guard expenses.allSatisfy({ $0.purchaseMonth.map(validMonth) ?? true }) else { throw FinanceError.invalid }
        guard expenses.allSatisfy({ e in e.firstInstallment.map { (1...e.installments).contains($0) && !e.recurring } ?? true }) else { throw FinanceError.invalid }
    }
}
enum SpendingPortion: String, CaseIterable, Identifiable {
    case total = "Total", mine = "Tu parte", mai = "Parte de otra persona"
    var id: String { rawValue }
}
struct MonthlyCategoryAmount: Identifiable {
    let month: Month
    let categoryID: UUID
    let cents: Int64
    var id: String { month.id + categoryID.uuidString }
}
enum FinanceError: LocalizedError {
    case invalid, csv(String)
    var errorDescription: String? {
        switch self { case .invalid: return "El archivo contiene datos inválidos o referencias faltantes."
        case .csv(let message): return message }
    }
}
func money(_ cents: Int64, currency: String = "ARS") -> String {
    let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = currency
    f.locale = Locale(identifier: "es_AR"); f.maximumFractionDigits = 2
    return f.string(from: NSNumber(value: Double(cents)/100)) ?? "0"
}
func parseCents(_ text: String) -> Int64? {
    guard text.trimmingCharacters(in: .whitespaces).range(of: #"^\d+(?:\.\d{3})*(?:,\d{1,2})?$"#, options: .regularExpression) != nil else { return nil }
    let clean = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
    guard let d = Decimal(string: clean, locale: Locale(identifier: "en_US_POSIX")), d > 0, d <= 1_000_000_000 else { return nil }
    var value = d * 100; var rounded = Decimal(); NSDecimalRound(&rounded, &value, 0, .plain)
    return NSDecimalNumber(decimal: rounded).int64Value
}

enum CSV {
    static func rows(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []; var row: [String] = []; var field = ""; var quoted = false
        let chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n")); var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if quoted && i+1 < chars.count && chars[i+1] == "\"" { field.append("\""); i += 1 } else { quoted.toggle() }
            } else if c == "," && !quoted { row.append(field); field = "" }
            else if c == "\n" && !quoted { row.append(field); if row.contains(where: { !$0.isEmpty }) { rows.append(row) }; row = []; field = "" }
            else { field.append(c) }
            i += 1
        }
        guard !quoted else { throw FinanceError.csv("CSV con comillas sin cerrar.") }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
    static let header = ["id_origen", "mes", "descripcion", "centavos", "moneda", "tarjeta", "categoria", "responsable", "pago", "nota"]
    static func preview(_ text: String, ledger: Ledger) throws -> [Expense] {
        let rows = try rows(text)
        guard rows.first == header else { throw FinanceError.csv("Usá el CSV de migración o el formato indicado en la guía.") }
        var result: [Expense] = []; var keys = Set(ledger.expenses.compactMap(\.sourceKey))
        for (index, r) in rows.dropFirst().enumerated() {
            guard r.count == 10 else { throw FinanceError.csv("Fila \(index+2): se esperaban 10 columnas.") }
            if keys.contains(r[0]) { continue }
            let ym = r[1].split(separator: "-").compactMap { Int($0) }
            guard !r[0].isEmpty, ym.count == 2, (2000...2200).contains(ym[0]), (1...12).contains(ym[1]),
                  let cents = Int64(r[3]), cents > 0, cents <= 100_000_000_000,
                  ["ARS", "USD"].contains(r[4]),
                  let wallet = ledger.wallets.first(where: { $0.name == r[5] }),
                  let category = ledger.categories.first(where: { $0.name == r[6] }),
                  let allocation = Allocation(rawValue: r[7]), let payer = Person(rawValue: r[8]) else {
                throw FinanceError.csv("Fila \(index+2): revisá mes, importe, tarjeta, categoría o persona.")
            }
            let m = Month(year: ym[0], month: ym[1])
            result.append(Expense(title: r[2], cents: cents, currency: r[4], date: m.date, firstMonth: m, walletID: wallet.id, categoryID: category.id, allocation: allocation, paidBy: payer, notes: r[9], sourceKey: r[0]))
            keys.insert(r[0])
        }
        return result
    }
    static func export(_ charges: [Charge], ledger: Ledger) -> String {
        let rows = [header] + charges.map { c in
            [c.id, c.month.id, c.expense.title, String(c.cents), c.expense.currency,
             ledger.wallets.first { $0.id == c.expense.walletID }?.name ?? "",
             ledger.categories.first { $0.id == c.expense.categoryID }?.name ?? "",
             c.expense.allocation.rawValue, c.expense.paidBy.rawValue,
             c.expense.notes + (c.installmentProgress.map { " · \($0.label)\($0.historical ? " (histórico)" : "")" } ?? "")]
        }
        return rows.map { $0.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") }.joined(separator: "\n")
    }
}

// Presentación genérica de la cuenta inicial, sin renombrar datos del usuario.
extension Wallet {
    var displayName: String { name == "Pagado por Mai" ? "Pagado por otra persona" : name }
}

extension Category {
    /// Misma paleta persistente para gráficos de la app y reportes externos.
    var reportColorHex: String {
        let fallback = id.uuidString.utf8.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
        let index = colorIndex ?? Int(fallback % 10000)
        let colors = ["286B55", "C39739", "4E83A8", "C07558", "8B76AB", "78A09A", "AA6D85", "8C9B50", "C18838", "627F9B", "A16A4D", "8D9274", "90958D"]
        if colors.indices.contains(index) { return colors[index] }
        let hue = (Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1)
        let h = (hue < 0 ? hue + 1 : hue) * 6, sector = Int(h), fraction = h - Double(sector)
        let v = 0.72, p = v * (1-0.42), q = v * (1-fraction*0.42), t = v * (1-(1-fraction)*0.42)
        let rgb: (Double, Double, Double)
        switch sector % 6 { case 0: rgb = (v,t,p); case 1: rgb = (q,v,p); case 2: rgb = (p,v,t); case 3: rgb = (p,q,v); case 4: rgb = (t,p,v); default: rgb = (v,p,q) }
        return String(format: "%02X%02X%02X", Int((rgb.0*255).rounded()), Int((rgb.1*255).rounded()), Int((rgb.2*255).rounded()))
    }
}

/// Balance personal del mes, calculado sin modificar movimientos ni mezclar monedas.
struct MonthlyOverview {
    let totalExpenses: Int64
    let personalExpenses: Int64
    let income: Int64
    let incomeCount: Int
    var otherExpenses: Int64 { totalExpenses-personalExpenses }
    var available: Int64 { income-personalExpenses }
}
extension Ledger {
    func monthlyOverview(in month: Month, currency: String) -> MonthlyOverview {
        let monthlyCharges = charges(in: month, currency: currency)
        let monthlyIncome = incomes.filter { $0.month == month && $0.currency == currency }
        return MonthlyOverview(totalExpenses: monthlyCharges.reduce(0) { $0+$1.cents }, personalExpenses: monthlyCharges.reduce(0) { $0+$1.agusShare }, income: monthlyIncome.reduce(0) { $0+$1.cents }, incomeCount: monthlyIncome.count)
    }
}
