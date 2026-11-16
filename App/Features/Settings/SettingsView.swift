import SwiftUI
import UniformTypeIdentifiers
import AppIntents

struct SettingsView: View {
    @Environment(Store.self) private var store
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .light
    @State private var importFile = false
    @State private var backupMode = false
    @State private var preview: [Expense] = []
    @State private var showPreview = false
    @State private var pendingBackup: Ledger?
    @State private var confirmRestore = false
    @State private var shareURL: URL?
    var body: some View {
        BolsilloList {
            Section {
                Toggle(isOn: Binding(
                    get: { appearance == .dark },
                    set: { appearance = $0 ? .dark : .light }
                )) {
                    Label("Modo oscuro", systemImage: "moon.fill")
                }
            } header: {
                Text("Apariencia")
            } footer: {
                Text("Apagado: tema claro. Encendido: tema oscuro. Se guarda tu elección, independientemente del dispositivo.")
            }
            Section("Organización") {
                NavigationLink("Tarjetas y cuentas") { WalletSettings() }
                NavigationLink("Secciones y categorías") { CategorySettings() }
                NavigationLink("Revisión masiva y reglas") { BulkReviewView() }
                NavigationLink("Resúmenes y vencimientos") { StatementsOverview() }
            }
            Section("Tus datos") {
                NavigationLink { CloudSettingsView() } label: { Label("Sincronización en la nube", systemImage: "icloud") }
                let historicalCount = store.ledger.expenses.filter { $0.sourceKey?.hasPrefix("planilla-2026-") == true }.count
                if historicalCount > 0 {
                    Label("\(historicalCount) cargos de tu planilla cargados", systemImage: "checkmark.circle")
                    Text("Histórico de 2026, incluidos gastos fijos explícitos. Los sueldos figuran en Ingresos. Revisá las categorías, responsables y las anotaciones pendientes de Mudanza.").font(.caption).foregroundStyle(Palette.muted)
                }
                NavigationLink("Completar planilla y revisar coincidencias") { SupplementalMigrationView() }
                NavigationLink("Respaldos automáticos y versiones") { BackupSettingsView() }
                NavigationLink { ExcelReportView() } label: { Label("Reporte Excel con gráficos", systemImage: "chart.bar.doc.horizontal") }
                Button("Exportar mes a CSV") { shareURL = store.exportURL(backup: false) }
                Button("Crear respaldo completo JSON") { shareURL = store.exportURL(backup: true) }
                if let shareURL { ShareLink(item: shareURL) { Label("Compartir archivo preparado", systemImage: "square.and.arrow.up") } }
                Button("Importar CSV con revisión") { backupMode = false; importFile = true }
                Button("Revisar planilla importada") { readBundled() }
                Button("Restaurar respaldo JSON") { backupMode = true; importFile = true }
            }
            Section("Acceso rápido") {
                NavigationLink { WalletAutomationSettings() } label: { Label("Apple Pay y Atajos", systemImage: "creditcard.and.123") }
                Label("Widget de pantalla de inicio", systemImage: "square.grid.2x2")
                Text("Mantené presionada la pantalla de inicio del iPhone, elegí Editar → Agregar widget y buscá Bolsillo. El botón + abre directamente la carga de gastos.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Privacidad y alcance") {
                Text("Los datos se guardan en este dispositivo. Exportá respaldos periódicamente. El resumen se puede compartir como texto y la nube personal se configura en Sincronización. No hay conexión bancaria.").font(.subheadline)
            }
        }.navigationTitle("Ajustes")
            .fileImporter(isPresented: $importFile, allowedContentTypes: backupMode ? [.json] : [.commaSeparatedText, .plainText]) { result in
                do {
                    let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    if backupMode { let decoded = try JSONDecoder().decode(Ledger.self, from: data); try decoded.validate(); pendingBackup = decoded; confirmRestore = true }
                    else { guard let text = String(data: data, encoding: .utf8) else { throw FinanceError.invalid }; try prepare(text) }
                } catch { store.error = error.localizedDescription }
            }
            .confirmationDialog("¿Reemplazar los datos con este respaldo?", isPresented: $confirmRestore, titleVisibility: .visible) { Button("Restaurar respaldo", role: .destructive) { if let pendingBackup { store.persist(pendingBackup, restoring: true) } } } message: { Text("Se reemplazan todos los gastos, cuentas, presupuestos y devoluciones actuales.") }
            .sheet(isPresented: $showPreview) { NavigationStack { BolsilloList {
                Section { Text("\(preview.count) cargos por importar").font(.headline); Text("Las filas de la planilla son cargos históricos de cada mes, no planes nuevos de cuotas. Se omiten totales, sueldos, gastos fijos y hojas Mudanza para evitar duplicados. Tarjetas, categorías y responsables necesitan tu revisión. Podés corregir cada gasto después de importar.").font(.caption); Text("Los nombres que aparecen en la descripción no determinan a quién corresponde el gasto: los cargos quedan como Mío hasta que los revises.").font(.caption).foregroundStyle(Palette.warning) }
                ForEach(preview) { e in VStack(alignment: .leading, spacing: 4) { Text(e.title).font(.subheadline.bold()); Text("\(e.firstMonth.label) · \(money(e.cents, currency: e.currency))").font(.caption); Text(e.notes).font(.caption2).foregroundStyle(Palette.muted) } }
            }.navigationTitle("Revisar importación").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showPreview = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Importar") { store.commit { $0.expenses.append(contentsOf: preview) }; if store.error == nil { showPreview = false } }.disabled(preview.isEmpty) }
            } } }
    }
    func prepare(_ text: String) throws { preview = try CSV.preview(text, ledger: store.ledger); showPreview = true }
    func readBundled() {
        do { guard let url = Bundle.main.url(forResource: "historico-revisar", withExtension: "csv") else { throw FinanceError.csv("No se encontró el CSV de referencia.") }; try prepare(String(contentsOf: url, encoding: .utf8)) }
        catch { store.error = error.localizedDescription }
    }
}
