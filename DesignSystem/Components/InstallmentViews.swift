import SwiftUI
import Charts
import UniformTypeIdentifiers

struct InstallmentBadge: View {
    let progress: InstallmentProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(progress.label, systemImage: "square.stack.3d.up")
                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                    .padding(.horizontal, 9).padding(.vertical, 5).background(Palette.softGreen, in: Capsule())
                Spacer(minLength: 4)
                Text(progress.remaining == 0 ? "Última cuota" : "\(progress.remaining) restantes").font(.caption2).foregroundStyle(Palette.muted)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.outline.opacity(0.45))
                    Capsule().fill(Palette.accent).frame(width: geometry.size.width * progress.fraction)
                }
            }.frame(height: 4).accessibilityHidden(true)
        }.accessibilityElement(children: .combine)
    }
}

struct InstallmentDetail: View {
    let charge: Charge
    var body: some View {
        if let progress = charge.installmentProgress {
            ExpenseCard(title: "Tu plan de cuotas", symbol: "square.stack.3d.up") {
                InstallmentBadge(progress: progress)
                LabeledContent("Cuota de \(charge.month.label)", value: money(charge.cents, currency: charge.expense.currency))
                if !progress.historical {
                    LabeledContent("Total de la compra", value: money(charge.expense.cents, currency: charge.expense.currency))
                    let remaining = (1..<(progress.remaining+1)).reduce(Int64(0)) { sum, offset in sum + (charge.expense.occurrence(in: charge.month.adding(offset))?.cents ?? 0) }
                    LabeledContent("Cuotas futuras", value: money(remaining, currency: charge.expense.currency))
                }
                LabeledContent(progress.historical ? "Fin estimado" : "Última cuota", value: progress.lastMonth.label)
                Text(progress.historical ? "Cuota informada en tu planilla. Este registro representa solo este mes y no genera cargos futuros. El total original no está confirmado." : "El avance indica la cuota del mes seleccionado; no confirma que se haya pagado el resumen.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
}
