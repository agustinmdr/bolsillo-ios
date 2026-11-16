import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct BackupSettingsView: View {
    @Environment(Store.self) private var store
    @State private var chooseFolder = false
    @State private var selectedBackup: URL?
    @State private var restoring = false
    @State private var folderName = UserDefaults.standard.string(forKey: "backupFolderName")
    var body: some View {
        BolsilloList {
            Section("Respaldo automático local") {
                Label("Activado al guardar cambios", systemImage: "checkmark.shield")
                Text("Se conservan hasta 30 versiones. Antes de reemplazar datos se protege la versión anterior; un respaldo inválido no se restaura.").font(.caption).foregroundStyle(Palette.muted)
                Text("Las copias locales están dentro de la app y pueden perderse al desinstalarla. Elegí una carpeta externa para protegerte también de esa situación.").font(.caption).foregroundStyle(Palette.warning)
                Button("Crear respaldo ahora") { store.createBackupNow() }
            }
            Section("Copia automática en Archivos") {
                if let folderName { LabeledContent("Carpeta elegida", value: folderName) }
                Button(folderName == nil ? "Elegir carpeta de respaldo" : "Cambiar carpeta") { chooseFolder = true }
                if folderName != nil { Button("Desactivar copia externa") { store.disableExternalBackup(); folderName = nil } }
                Text("Podés elegir una carpeta de iCloud Drive o de otro proveedor en Archivos. Después de cada guardado, Bolsillo copia el respaldo allí; la sincronización depende de ese proveedor. No es sincronización en vivo con otras personas.").font(.caption).foregroundStyle(Palette.muted)
                if let notice = store.backupNotice { Text(notice).font(.caption) }
            }
            Section("Versiones disponibles") {
                ForEach(store.backupURLs, id: \.self) { url in
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(((try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()).formatted(date: .abbreviated, time: .standard)).font(.subheadline)
                            Text("\(((try? Data(contentsOf: url).count) ?? 0)/1024) KB").font(.caption).foregroundStyle(Palette.muted)
                        }
                        HStack {
                            ShareLink(item: url) { Label("Exportar", systemImage: "square.and.arrow.up") }
                            Spacer()
                            Button("Restaurar") { selectedBackup = url; restoring = true }
                        }
                    }
                }
            }
        }.navigationTitle("Respaldos automáticos").navigationBarTitleDisplayMode(.inline).onAppear { store.refreshBackupList() }
            .fileImporter(isPresented: $chooseFolder, allowedContentTypes: [.folder]) { result in
                do { let url = try result.get(); store.setExternalBackupFolder(url); folderName = UserDefaults.standard.string(forKey: "backupFolderName") }
                catch { store.error = error.localizedDescription }
            }
            .confirmationDialog("¿Restaurar esta versión completa?", isPresented: $restoring, titleVisibility: .visible) { Button("Restaurar versión", role: .destructive) { if let selectedBackup { store.restoreBackup(selectedBackup) } } } message: { Text("Reemplaza gastos, ingresos, reglas, resúmenes y cierres. La versión actual queda en los respaldos locales.") }
    }
}
