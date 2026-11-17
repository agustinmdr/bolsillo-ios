import SwiftUI
import Charts

struct SpendingForecastView: View {
    @Environment(Store.self) private var store
    @State private var count = 6
    @State private var portion: SpendingPortion = .mine
    @State private var selected: Month?
    private var forecast: SpendingForecast { store.ledger.forecast(startingAt: store.month, count: count, currency: store.currency, portion: portion) }
    private var month: Month { forecast.months.contains(selected ?? store.month) ? (selected ?? store.month) : store.month }
    private var colors: [Color] { [Palette.accent, Palette.categoryColor(Category(name: "Cuotas", symbol: "", section: "", colorIndex: 2)), Palette.muted, Palette.warning] }
    var body: some View {
        BolsilloList {
            Section { PeriodPicker(title: "Proyectar desde") }
            Section {
                HStack {
                    Picker("Parte a proyectar", selection: $portion) { ForEach(SpendingPortion.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).labelsHidden()
                    Spacer()
                    Picker("Horizonte", selection: $count) { Text("6 meses").tag(6); Text("12 meses").tag(12) }.pickerStyle(.menu).labelsHidden()
                }
                if forecast.amounts.allSatisfy({ $0.cents == 0 }) {
                    ContentUnavailableView("Sin compromisos registrados", systemImage: "calendar", description: Text("Agregá compras en cuotas o gastos recurrentes para ver los próximos meses."))
                } else {
                Chart(forecast.amounts.filter { $0.cents != 0 }) { row in
                    BarMark(x: .value("Mes", row.month.date, unit: .month), y: .value("Importe", Double(row.cents)/100))
                        .foregroundStyle(by: .value("Tipo", row.kind.rawValue)).cornerRadius(3)
                }.chartForegroundStyleScale(domain: ForecastKind.allCases.map(\.rawValue), range: colors)
                    .chartXScale(domain: store.month.date...store.month.adding(count).date.addingTimeInterval(-1))
                    .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(Palette.outline)
                            AxisValueLabel { if let amount = value.as(Double.self) { Text(amount.formatted(.number.notation(.compactName).locale(Locale(identifier: "es_AR")))) } }
                        }
                    }
                    .chartLegend(position: .bottom, alignment: .leading, spacing: 12).frame(height: 220)
                    .accessibilityLabel("Compromisos mensuales, separados en fijos, cuotas, otros cargos registrados y estimaciones")
                }
                VStack(alignment: .leading, spacing: 8) {
                Label("Las cuotas estimadas no son gastos nuevos", systemImage: "info.circle").font(.caption.weight(.medium)).foregroundStyle(Palette.warning)
                Text("Se usa el importe de la última cuota histórica de cada compra para estimar las restantes. Puede variar. Los fijos usan su importe actual. No se duplican cargos ni se infieren ingresos o nuevas compras.").font(.caption).foregroundStyle(Palette.muted)
                }
                if forecast.ambiguousSeries > 0 {
                    Text(forecast.ambiguousSeries == 1 ? "Un plan histórico necesita revisión: hay compras indistinguibles. No lo estimamos para evitar duplicados." : "\(forecast.ambiguousSeries) planes históricos necesitan revisión: hay compras indistinguibles. No los estimamos para evitar duplicados.").font(.caption).foregroundStyle(Palette.warning)
                    NavigationLink("Revisar gastos") { Movements() }
                }
            } header: { Text("Lo que tenés comprometido") }
            Section("Mes por mes · \(store.currency)") {
                ForEach(forecast.months) { row in
                    Button { selected = row } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.label.capitalized).font(.subheadline.weight(.medium))
                                if forecast.amounts.contains(where: { $0.month == row && $0.kind == .estimated && $0.cents > 0 }) { Text("Incluye cuotas estimadas").font(.caption2).foregroundStyle(Palette.warning) }
                            }
                            Spacer()
                            Text(money(forecast.total(in: row), currency: store.currency)).font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                            Image(systemName: row == month ? "checkmark.circle.fill" : "circle").foregroundStyle(row == month ? Palette.accent : Palette.outline)
                        }.foregroundStyle(Palette.text).padding(.vertical, 3)
                    }.buttonStyle(.plain)
                }
            }
            Section("Detalle · \(month.label)") {
                ForEach(forecast.amounts.filter { $0.month == month }) { row in
                    HStack { Circle().fill(colors[ForecastKind.allCases.firstIndex(of: row.kind)!]).frame(width: 8, height: 8); Text(row.kind.rawValue); Spacer(); Text(money(row.cents, currency: store.currency)).fontWeight(.medium).monospacedDigit() }.font(.subheadline)
                }
            }
            Section {
                if forecast.releases.isEmpty { Text("No hay planes de cuotas pendientes para este período.").foregroundStyle(Palette.muted) }
                ForEach(forecast.releases) { release in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(release.expense.displayTitle).font(.subheadline.weight(.semibold)); Spacer(); if release.estimated { Text("Estimado").font(.caption2.weight(.medium)).foregroundStyle(Palette.warning) } }
                        Text("Última cuota: \(release.lastMonth.label)").font(.caption).foregroundStyle(Palette.muted)
                        Label("Desde \(release.freedFrom.label): \(money(release.monthlyCents, currency: store.currency)) menos por mes", systemImage: "arrow.down.right").font(.caption).foregroundStyle(Palette.accent)
                    }.padding(.vertical, 5)
                }
            } header: { Text("Cuándo terminan tus cuotas") } footer: { Text("Importes según la parte seleccionada. La finalización de un plan no acredita que el resumen esté pagado.") }
        }.navigationTitle("Próximos meses").navigationBarTitleDisplayMode(.inline)
    }
}
