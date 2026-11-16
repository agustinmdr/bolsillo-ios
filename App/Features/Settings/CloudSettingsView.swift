import SwiftUI
import UniformTypeIdentifiers

struct CloudSettingsView: View {
    @Environment(Store.self) private var store
    @State private var endpoint = ""
    @State private var token = ""
    @State private var choice: Choice?
    @State private var importing = false
    @State private var importMessage: String?
    private struct ConnectionFile: Decodable { let endpoint: String; let token: String }
    private enum Choice: String, Identifiable { case local, cloud, disconnect; var id: String { rawValue } }
    var body: some View {
        BolsilloList {
            Section("Estado") {
                Label(store.cloud.enabled ? "Conexión configurada" : "Solo en este dispositivo", systemImage: store.cloud.enabled ? "icloud" : "iphone")
                Text(store.cloud.message).font(.subheadline).foregroundStyle(Palette.muted)
                if store.cloud.syncing { ProgressView() }
                if let date = store.cloud.lastSync { Text("Última sincronización: \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(Palette.muted) }
                if store.cloud.enabled {
                    Text(store.cloud.endpoint).font(.caption).textSelection(.enabled)
                    Button("Sincronizar ahora") { Task { await store.cloud.synchronize(store: store) } }.disabled(store.cloud.syncing)
                }
            }
            if let remote = store.cloud.conflict {
                Section("Revisar las dos copias") {
                    Text("Dispositivo: \(store.ledger.expenses.count) gastos · \(store.ledger.incomes.count) ingresos")
                    Text("Nube (versión \(remote.revision)): \(remote.ledger?.expenses.count ?? 0) gastos · \(remote.ledger?.incomes.count ?? 0) ingresos")
                    Text("Las copias no se mezclan automáticamente para evitar duplicados. Elegí la que querés conservar. Antes de reemplazar se protege la versión anterior en los respaldos.").font(.caption).foregroundStyle(Palette.muted)
                    Button("Usar la copia de la nube en este dispositivo") { choice = .cloud }.disabled(remote.ledger == nil || store.cloud.syncing)
                    Button("Conservar este dispositivo y actualizar la nube") { choice = .local }.disabled(store.loadFailed || store.cloud.syncing)
                }
            }
            Section(store.cloud.enabled ? "Cambiar conexión" : "Conectar tu base") {
                Button("Importar archivo de conexión") { importing = true }
                if let importMessage { Text(importMessage).font(.caption).foregroundStyle(Palette.muted) }
                TextField("https://tu-api.onrender.com", text: $endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Clave privada de sincronización", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(store.cloud.enabled ? "Guardar nueva conexión" : "Conectar y sincronizar") {
                    Task { await store.cloud.connect(endpoint: endpoint, token: token, store: store); token = "" }
                }.disabled(endpoint.isEmpty || token.isEmpty || store.cloud.syncing)
                Text("Usá la dirección y clave de tu API personal. Al conectar, se envía tu historial financiero a ese servidor. La contraseña de PostgreSQL queda solo en el servidor; la clave de la app se guarda en el llavero de este dispositivo.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Tus datos siguen disponibles") {
                Text("Podés cargar gastos sin conexión. Los cambios se guardan primero acá y se intenta sincronizarlos al guardar o volver a abrir la app. Si no hay conexión, reintentá con Sincronizar ahora. Los respaldos locales siguen activos.").font(.subheadline)
                Text("La API gratuita de Render puede tardar al despertar. Esta conexión corresponde a tu historial personal; no agrega cuentas independientes ni invitaciones para otras personas.").font(.caption).foregroundStyle(Palette.muted)
                if store.cloud.enabled { Button("Desconectar este dispositivo", role: .destructive) { choice = .disconnect }.disabled(store.cloud.syncing) }
            }
        }.navigationTitle("Sincronización").navigationBarTitleDisplayMode(.inline)
            .onAppear { endpoint = store.cloud.endpoint }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(), access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    guard data.count < 4096 else { throw CloudError.invalidResponse }
                    let config = try JSONDecoder().decode(ConnectionFile.self, from: data)
                    let checked = try CloudSyncRules.endpoint(config.endpoint)
                    guard (32...512).contains(config.token.utf8.count), config.token.utf8.allSatisfy({ (33...126).contains($0) }) else { throw CloudError.invalidResponse }
                    endpoint = checked.absoluteString; token = config.token
                    importMessage = "Configuración preparada. Revisá la dirección y tocá Conectar y sincronizar para activarla."
                } catch { importMessage = "No se pudo importar la conexión: \(error.localizedDescription)" }
            }
            .confirmationDialog("Confirmar cambio de datos", isPresented: Binding(get: { choice != nil }, set: { if !$0 { choice = nil } }), titleVisibility: .visible, presenting: choice) { selected in
                switch selected {
                case .cloud: Button("Reemplazar con la copia de la nube") { store.cloud.useCloud(store: store); choice = nil }
                case .local: Button("Actualizar la nube con este dispositivo") { Task { await store.cloud.useLocal(store: store) }; choice = nil }
                case .disconnect: Button("Desconectar", role: .destructive) { store.cloud.disconnect(); choice = nil }
                }
            } message: { selected in
                Text(selected == .disconnect ? "Se conserva el historial local y los datos que ya están en la nube." : "Se reemplaza una copia completa. Los gastos no se suman entre ambas versiones. Se conservan respaldos para recuperación.")
            }
    }
}
