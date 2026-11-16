import SwiftUI
import UniformTypeIdentifiers
import AppIntents

struct ExcelReportView: View {
    @Environment(Store.self) private var store
    @State private var generating = false
    @State private var share: ExcelShare?
    @State private var lastURL: URL?
    var body: some View {
        BolsilloList {
            Section { PeriodPicker().disabled(generating) } footer: { Text("El archivo incluye ARS y USD en resúmenes separados, independientemente de la moneda que estés viendo.") }
            Section("Tu mes en Excel") {
                Label("Resumen y gráfico por categoría en cada moneda", systemImage: "chart.bar.xaxis")
                Label("Mío, Compartido y De otra persona", systemImage: "person.2")
                Label("Detalle de gastos, tarjetas y cuotas del mes", systemImage: "list.bullet.rectangle")
                Label("Ingresos y disponible personal", systemImage: "arrow.down.circle")
                Text("Se exporta lo registrado, incluidos los cargos pendientes de revisión. Los reintegros restan y las cuotas incluyen solo el cargo de este mes. El disponible es ingresos menos tu parte de los gastos; no representa el saldo de tu banco.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section {
                Button {
                    generating = true
                    Task {
                        if let url = await store.exportExcel() { lastURL = url; share = ExcelShare(url: url) }
                        generating = false
                    }
                } label: {
                    HStack { if generating { ProgressView() }; Label(generating ? "Generando reporte…" : "Generar y compartir Excel", systemImage: "square.and.arrow.up") }
                }.disabled(generating)
                if let lastURL { ShareLink(item: lastURL) { Label("Compartir último reporte generado", systemImage: "doc.richtext") } }
            } footer: { Text("Elegí Guardar en Archivos, AirDrop o la app con la que quieras compartirlo. Es una copia del mes; los cambios en Excel no modifican Bolsillo.") }
        }.navigationTitle("Reporte Excel").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $share) { item in ExcelActivitySheet(url: item.url) }
    }
}
private struct ExcelActivitySheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct ExcelShare: Identifiable { let url: URL; var id: URL { url } }
