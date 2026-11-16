import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/private/tmp/BolsilloExcelQA", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let month = Month(year: 2026, month: 11)
var ledger = Ledger()
let wallet = ledger.wallets[0].id
let categories = [Category(name: "Tecnología & herramientas", symbol: "hammer", section: "Compras", colorIndex: 0), Category(name: "Casa * ? ~", symbol: "house", section: "Casa", colorIndex: 2), Category(name: "Reintegros", symbol: "arrow.uturn.backward", section: "Otros", colorIndex: 14)]
ledger.categories = categories
ledger.expenses = [
    Expense(title: "Notebook <nueva>", cents: 10000, firstMonth: month.adding(-1), installments: 3, walletID: wallet, categoryID: categories[0].id, allocation: .shared),
    Expense(title: "=HYPERLINK(\"https://example.com\")", cents: 5000, firstMonth: month, walletID: wallet, categoryID: categories[1].id),
    Expense(title: "Compra para otra persona", cents: 8000, firstMonth: month, walletID: wallet, categoryID: categories[1].id, allocation: .mai),
    Expense(title: "Licencia USD", cents: 1250, currency: "USD", firstMonth: month, walletID: wallet, categoryID: categories[0].id, paidBy: .mai),
    Expense(title: "Mes siguiente excluido", cents: 9999999, firstMonth: month.adding(1), walletID: wallet, categoryID: categories[0].id)
]
ledger.incomes = [Income(month: month, title: "Sueldo", cents: 100000, currency: "ARS"), Income(month: month, title: "Honorarios", cents: 20000, currency: "USD"), Income(month: month.adding(-1), title: "Excluido", cents: 9000000, currency: "ARS")]
ledger.ops.adjustments = [StatementAdjustment(walletID: wallet, month: month, currency: "ARS", title: "Reintegro & ajuste", cents: 101, kind: .refund, categoryID: categories[2].id, allocation: .shared)]
let original = try LedgerStorage.data(ledger)
try ExcelReport.data(ledger: ledger, month: month).write(to: output.appendingPathComponent("mixto.xlsx"))
let after = try LedgerStorage.data(ledger)
precondition(after == original, "Exportar no cambia los datos")
var empty = Ledger(); empty.expenses = []; empty.incomes = []
try ExcelReport.data(ledger: empty, month: month).write(to: output.appendingPathComponent("vacio.xlsx"))
var invalid = ledger; invalid.expenses[0].cents = -1
do { _ = try ExcelReport.data(ledger: invalid, month: month); fatalError("Debe rechazar ledger inválido") } catch {}
var large = ledger
large.expenses.append(Expense(title: "Importe máximo", cents: 100_000_000_000, firstMonth: month, walletID: wallet, categoryID: categories[0].id))
try ExcelReport.data(ledger: large, month: month).write(to: output.appendingPathComponent("maximo.xlsx"))
if CommandLine.arguments.count > 2 {
    let real = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
    try ExcelReport.data(ledger: real, month: month).write(to: output.appendingPathComponent("Bolsillo-2026-11.xlsx"))
    print("Reporte real: \(real.charges(in: month, currency: "ARS").count) cargos ARS, \(real.charges(in: month, currency: "USD").count) USD")
}
print("Reportes generados sin mutar el ledger; datos inválidos rechazados.")
