import Foundation

enum ForecastKind: String, CaseIterable, Identifiable {
    case recurring = "Fijos", installments = "Cuotas", recorded = "Otros registrados", estimated = "Cuotas estimadas"
    var id: String { rawValue }
}
struct ForecastAmount: Identifiable {
    let month: Month
    let kind: ForecastKind
    let cents: Int64
    var id: String { month.id + kind.id }
}
struct InstallmentRelease: Identifiable {
    let expense: Expense
    let lastMonth: Month
    let monthlyCents: Int64
    let estimated: Bool
    var id: UUID { expense.id }
    var freedFrom: Month { lastMonth.adding(1) }
}
struct SpendingForecast {
    let months: [Month]
    let amounts: [ForecastAmount]
    let releases: [InstallmentRelease]
    let ambiguousSeries: Int
    func total(in month: Month) -> Int64 { amounts.filter { $0.month == month }.reduce(0) { $0 + $1.cents } }
}

extension Ledger {
    /// Vista calculada: las estimaciones históricas nunca se agregan al ledger.
    func forecast(startingAt start: Month, count: Int, currency: String, portion: SpendingPortion = .mine) -> SpendingForecast {
        let months = (0..<min(max(count, 1), 12)).map { start.adding($0) }
        func share(_ charge: Charge) -> Int64 {
            switch portion { case .total: return charge.cents; case .mine: return charge.agusShare; case .mai: return charge.maiShare }
        }
        var rows: [ForecastAmount] = []
        for month in months {
            let charges = charges(in: month, currency: currency)
            for kind in ForecastKind.allCases where kind != .estimated {
                let sum = charges.filter { charge in
                    let actual: ForecastKind = charge.expense.recurring ? .recurring : charge.installmentProgress != nil ? .installments : .recorded
                    return actual == kind
                }.reduce(Int64(0)) { $0 + share($1) }
                rows.append(ForecastAmount(month: month, kind: kind, cents: sum))
            }
        }
        var releases: [InstallmentRelease] = []
        for expense in expenses where expense.currency == currency && !expense.recurring && expense.installments > 1 {
            let end = expense.firstMonth.adding(expense.installments - expense.firstInstallmentNumber)
            if end >= start, let last = expense.occurrence(in: end), share(last) > 0 {
                releases.append(InstallmentRelease(expense: expense, lastMonth: end, monthlyCents: share(last), estimated: false))
            }
        }
        // Dos compras indistinguibles en un mismo mes no permiten reconstruir una serie con certeza.
        struct SeriesKey: Hashable { let wallet: UUID; let title: String; let total: Int; let first: Month }
        let activeIDs = Set(activeWallets.map(\.id))
        let snapshots = expenses.filter { $0.currency == currency && $0.historicalInstallment != nil && activeIDs.contains($0.walletID) }
        let groups = Dictionary(grouping: snapshots) { expense in
            let report = expense.historicalInstallment!
            return SeriesKey(wallet: expense.walletID, title: normalized(expense.displayTitle), total: report.total, first: expense.firstMonth.adding(1-report.number))
        }
        var estimated: [Month: Int64] = [:]
        var ambiguous = 0
        for (key, group) in groups {
            // Si se reconstruyó el mismo plan como compra nativa, esa serie ya se proyecta.
            if expenses.contains(where: { $0.currency == currency && !$0.recurring && $0.installments == key.total && $0.walletID == key.wallet && $0.firstMonth.adding(1-$0.firstInstallmentNumber) == key.first && normalized($0.displayTitle) == key.title }) { continue }
            guard let latest = group.max(by: { $0.firstMonth < $1.firstMonth }), let report = latest.historicalInstallment else { continue }
            let end = latest.firstMonth.adding(report.total-report.number)
            guard end >= start else { continue }
            guard Dictionary(grouping: group, by: \.firstMonth).values.allSatisfy({ $0.count == 1 }) else { ambiguous += 1; continue }
            for month in months where month > latest.firstMonth && month <= end {
                let charge = Charge(expense: latest, month: month, cents: latest.cents, number: report.number + latest.firstMonth.distance(to: month))
                estimated[month, default: 0] += share(charge)
            }
            if report.number < report.total {
                let monthly = share(Charge(expense: latest, month: latest.firstMonth, cents: latest.cents, number: report.number))
                if monthly > 0 { releases.append(InstallmentRelease(expense: latest, lastMonth: end, monthlyCents: monthly, estimated: true)) }
            }
        }
        rows += months.map { ForecastAmount(month: $0, kind: .estimated, cents: estimated[$0, default: 0]) }
        return SpendingForecast(months: months, amounts: rows, releases: releases.sorted { $0.lastMonth == $1.lastMonth ? $0.expense.displayTitle < $1.expense.displayTitle : $0.lastMonth < $1.lastMonth }, ambiguousSeries: ambiguous)
    }
}
