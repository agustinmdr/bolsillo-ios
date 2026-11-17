import Foundation

enum WalletCaptureError: LocalizedError {
    case missingAmount, missingMerchant, missingWallet, archivedWallet, invalidCurrency
    var errorDescription: String? {
        switch self {
        case .missingAmount: return "Falta un importe válido. En Atajos, vinculá Importe a Amount de la transacción de Wallet. No se guardó el gasto."
        case .missingMerchant: return "Falta el comercio. En Atajos, vinculá Comercio a Merchant de la transacción. No se guardó el gasto."
        case .archivedWallet: return "La tarjeta fue quitada. Restaurala en Bolsillo o elegí otra en la automatización."
        case .missingWallet: return "La tarjeta seleccionada ya no existe en Bolsillo. Volvé a elegirla en la automatización."
        case .invalidCurrency: return "La moneda debe ser ARS o USD. No se guardó el gasto."
        }
    }
}

struct WalletCapture {
    let amount: Decimal
    let merchant: String
    let currency: String
    let walletID: UUID
    let date: Date
    var statementMonth: Month? = nil
    var eventID: String? = nil
    var walletLabel: String? = nil

    func apply(to ledger: inout Ledger) throws -> Bool {
        guard amount > 0, amount <= 1_000_000_000, !amount.isNaN else { throw WalletCaptureError.missingAmount }
        var raw = amount * 100; var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 0, .plain)
        guard raw == rounded else { throw WalletCaptureError.missingAmount }
        let cents = NSDecimalNumber(decimal: rounded).int64Value
        let clean = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 500 else { throw WalletCaptureError.missingMerchant }
        guard ["ARS", "USD"].contains(currency) else { throw WalletCaptureError.invalidCurrency }
        guard let wallet = ledger.wallets.first(where: { $0.id == walletID }) else { throw WalletCaptureError.missingWallet }
        guard !wallet.isArchived else { throw WalletCaptureError.archivedWallet }
        let identifier = eventID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceKey = identifier.flatMap { $0.isEmpty ? nil : "apple-pay-id:" + $0 }
        let duplicate = ledger.expenses.contains { e in
            if let sourceKey { return e.sourceKey == sourceKey }
            // Wallet no siempre proporciona un ID. Se informa una posible repetición,
            // en lugar de suponer que dos cobros iguales son la misma operación bancaria.
            return e.sourceKey?.hasPrefix("apple-pay-") == true && e.walletID == walletID && e.currency == currency && e.cents == cents && e.title.localizedCaseInsensitiveCompare(clean) == .orderedSame && abs(e.date.timeIntervalSince(date)) <= 10
        }
        if duplicate { return false }
        let category: Category
        if let existing = ledger.categories.first(where: { $0.name == "Sin categorizar" }) { category = existing }
        else {
            category = Category(name: "Sin categorizar", symbol: "square.grid.2x2.fill", section: "Otros")
            ledger.categories.append(category)
        }
        let label = walletLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ledger.expenses.append(Expense(title: clean, cents: cents, currency: currency, date: date, firstMonth: statementMonth ?? wallet.suggestedStatementMonth(for: date), walletID: walletID, categoryID: category.id, paidBy: wallet.owner, notes: "Capturado desde una automatización de Wallet. Revisar categoría, responsable, mes de resumen y cuotas." + (label.isEmpty ? "" : " Tarjeta informada por Wallet: \(label)."), tags: "Apple Pay, Por revisar", sourceKey: sourceKey ?? "apple-pay-local:" + UUID().uuidString))
        return true
    }
}
