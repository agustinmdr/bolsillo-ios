import SwiftUI
import Charts
import UniformTypeIdentifiers

struct ChargeRow: View {
    @Environment(Store.self) private var store
    let charge: Charge
    var amountsVisible = true
    var body: some View {
        let e = charge.expense
        let category = store.ledger.categories.first { $0.id == e.categoryID }
        VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 12) {
            Image(systemName: category?.symbol ?? "bag").font(.body).foregroundStyle(e.allocation.ownershipColor).frame(width: 42, height: 42).background(e.allocation.ownershipBackground, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(e.displayTitle).font(.subheadline.weight(.medium))
                Text([category?.name ?? "", e.isAdjustment ? e.tags : e.recurring ? "Recurrente" : ""].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(Palette.muted)
                Text(store.ledger.wallets.first { $0.id == e.walletID }?.displayName ?? "").font(.caption2).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(amountsVisible ? money(charge.cents, currency: e.currency) : "••••").accessibilityLabel(amountsVisible ? money(charge.cents, currency: e.currency) : "Importe oculto").font(.subheadline.bold()).multilineTextAlignment(.trailing)
                if charge.installmentProgress != nil { Text("este mes").font(.caption2).foregroundStyle(Palette.muted) }
            }
        }
        AllocationBadge(allocation: e.allocation).padding(.leading, 54)
        if let purchaseMonth = e.purchaseMonth {
            VStack(alignment: .leading, spacing: 3) {
                Text("Consumo: \(purchaseMonth.label)")
                Text("Resumen / pago: \(charge.month.label)")
            }.font(.caption2).foregroundStyle(Palette.muted).padding(.leading, 54)
        }
        if let progress = charge.installmentProgress {
            InstallmentBadge(progress: progress).padding(.leading, 54)
        }
        }.padding(.vertical, 4)
    }
}
