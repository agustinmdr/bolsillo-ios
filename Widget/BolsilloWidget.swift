import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let total: Int64
    let label: String
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), total: 0, label: Month().label) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) { completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(900)))) }
    func entry() -> Entry {
        let d = UserDefaults(suiteName: "group.com.agustin.bolsillo")
        let label = Month().label
        let expenses = d?.data(forKey: "expenses").flatMap { try? JSONDecoder().decode([Expense].self, from: $0) } ?? []
        let adjustments = d?.data(forKey: "adjustments").flatMap { try? JSONDecoder().decode([StatementAdjustment].self, from: $0) } ?? []
        let total = expenses.filter { $0.currency == "ARS" }.compactMap { $0.occurrence(in: Month()) }.reduce(Int64(0)) { $0+$1.cents }
            + adjustments.filter { $0.currency == "ARS" && $0.month == Month() }.reduce(Int64(0)) { $0+$1.signedCents }
        return Entry(date: Date(), total: total, label: label)
    }
}
struct WidgetView: View {
    var entry: Entry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if family == .accessoryCircular {
            Image(systemName: "plus.circle.fill").widgetURL(URL(string: "bolsillo://nuevo"))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Label("Bolsillo", systemImage: "wallet.bifold.fill").font(.caption.bold()); Spacer() }
                Text(entry.label.capitalized).font(.caption).foregroundStyle(Palette.muted)
                Text(money(entry.total)).font(.title2.bold()).minimumScaleFactor(0.5).lineLimit(1)
                Link(destination: URL(string: "bolsillo://nuevo")!) { Label("Nuevo gasto", systemImage: "plus.circle.fill").font(.subheadline.bold()) }
            }.foregroundStyle(Palette.text).tint(Palette.accent).containerBackground(Palette.surface, for: .widget).widgetURL(URL(string: "bolsillo://nuevo"))
        }
    }
}
@main struct BolsilloWidget: Widget {
    let kind = "BolsilloQuickAdd"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { WidgetView(entry: $0) }
            .configurationDisplayName("Registrar un gasto").description("Tu total mensual en pesos y acceso directo para cargar gastos.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
