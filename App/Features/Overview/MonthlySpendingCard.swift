import SwiftUI
import Charts

struct MonthlySpendingCard: View {
    @Environment(Store.self) private var store
    var amountsVisible = true
    @State private var monthsCount = 6
    @State private var portion: SpendingPortion = .total
    @State private var selectedID: String?
    private var months: [Month] { (0..<monthsCount).map { store.month.adding($0-monthsCount+1) } }
    private var rows: [MonthlyCategoryAmount] { store.ledger.monthlySpending(endingAt: store.month, count: monthsCount, currency: store.currency, portion: portion) }
    private var selectedMonth: Month { months.first { $0.id == selectedID } ?? store.month }
    private var activeCategories: [Category] { store.ledger.categories.filter { category in rows.contains { $0.categoryID == category.id && $0.cents != 0 } } }
    private var selectedRows: [MonthlyCategoryAmount] { rows.filter { $0.month == selectedMonth && $0.cents != 0 }.sorted { $0.cents > $1.cents } }
    private var selectedTotal: Int64 { selectedRows.reduce(0) { $0+$1.cents } }
    var body: some View {
        Tile {
            HStack {
                Text("Gastos por mes").font(.headline)
                Spacer()
                Menu {
                    Button("6 meses") { monthsCount = 6; selectedID = nil }
                    Button("12 meses") { monthsCount = 12; selectedID = nil }
                } label: { Label("\(monthsCount) meses", systemImage: "chevron.down").font(.caption.weight(.semibold)) }
            }
            HStack {
                Menu {
                    ForEach(SpendingPortion.allCases) { option in Button(option.rawValue) { portion = option } }
                } label: { Label(portion.rawValue, systemImage: "person.2").font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 7).background(Palette.inset, in: Capsule()) }
                Spacer()
                Text(store.currency).font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
            }
            Text("\(months.first!.label) — \(store.month.label)").font(.caption2).foregroundStyle(Palette.muted)
            if !amountsVisible {
                Label("Gráfico e importes ocultos", systemImage: "eye.slash").font(.subheadline).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, minHeight: 80)
            } else if activeCategories.isEmpty {
                ContentUnavailableView("Sin gastos registrados", systemImage: "chart.bar.xaxis", description: Text("Elegí otro período o registrá un gasto para ver la comparación."))
            } else {
                spendingChart
                Text("Tocá o deslizá sobre una barra para ver ese mes.").font(.caption2).foregroundStyle(Palette.muted)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 9) {
                    ForEach(activeCategories) { category in
                        HStack(spacing: 6) { Circle().fill(Palette.categoryColor(category)).frame(width: 8, height: 8); Text(category.name).font(.caption2).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
                    }
                }
                BolsilloDivider()
                HStack(alignment: .firstTextBaseline) {
                    Menu {
                        ForEach(months) { month in Button(month.label) { selectedID = month.id } }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(selectedMonth.label, systemImage: "chevron.down").font(.subheadline.weight(.semibold))
                            Text(portion.rawValue).font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }.accessibilityLabel("Elegir mes del detalle: \(selectedMonth.label)")
                    Spacer()
                    Text(money(selectedTotal, currency: store.currency)).font(.headline).minimumScaleFactor(0.65).lineLimit(1)
                }
                if selectedRows.isEmpty { Text("No hay gastos registrados para este mes.").font(.caption).foregroundStyle(Palette.muted) }
                ForEach(selectedRows) { row in
                    if let category = store.ledger.categories.first(where: { $0.id == row.categoryID }) {
                        HStack {
                            Circle().fill(Palette.categoryColor(category)).frame(width: 8, height: 8)
                            Label(category.name, systemImage: category.symbol).font(.caption)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(money(row.cents, currency: store.currency)).font(.caption.weight(.semibold))
                                Text(row.cents < 0 ? "Reintegro neto" : selectedTotal > 0 ? "\(Int((Double(row.cents)/Double(selectedTotal)*100).rounded()))%" : "Gasto").font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                if selectedRows.contains(where: { row in store.ledger.categories.contains { $0.id == row.categoryID && $0.name == "Sin categorizar" } }) {
                    Label("Los gastos sin categorizar aparecen con su propio color. Podés asignarles una categoría desde Gastos.", systemImage: "info.circle").font(.caption2).foregroundStyle(Palette.muted)
                }
            }
            Text("Por mes de resumen: cuotas, recurrentes y ajustes registrados. Los reintegros descuentan gasto; no son ingresos.").font(.caption2).foregroundStyle(Palette.muted)
        }
        .onChange(of: store.month) { _, _ in selectedID = nil }
    }
    private var spendingChart: some View {
        Chart {
            ForEach(rows.filter { $0.cents != 0 }) { row in
                BarMark(x: .value("Mes", row.month.id), y: .value("Gasto", Double(row.cents)/100), width: .ratio(0.64), stacking: .standard)
                    .foregroundStyle(by: .value("Categoría", row.categoryID.uuidString))
                    .accessibilityLabel("\(row.month.label), \(store.ledger.categories.first { $0.id == row.categoryID }?.name ?? "Categoría")")
                    .accessibilityValue(money(row.cents, currency: store.currency))
            }
            if selectedID != nil {
                RuleMark(x: .value("Mes seleccionado", selectedMonth.id)).foregroundStyle(Palette.muted.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXScale(domain: months.map(\.id))
        .chartForegroundStyleScale(domain: store.ledger.categories.map { $0.id.uuidString }, range: store.ledger.categories.map { Palette.categoryColor($0) })
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedID)
        .chartXAxis {
            AxisMarks(values: months.map(\.id)) { value in
                if let key = value.as(String.self), let month = months.first(where: { $0.id == key }) {
                    AxisValueLabel { Text(month.date.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "es_AR"))).replacingOccurrences(of: ".", with: "")).font(.system(size: monthsCount == 12 ? 9 : 11)).foregroundStyle(Palette.muted) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Palette.outline.opacity(0.5))
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.notation(.compactName)).foregroundStyle(Palette.muted)
            }
        }
        .frame(height: 210)
    }
}
