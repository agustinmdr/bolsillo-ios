import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct ReminderSettingsView: View {
    @Environment(Store.self) private var store
    @AppStorage("cardRemindersEnabled") private var enabled = false
    @State private var requesting = false
    @State private var message = ""
    var body: some View {
        BolsilloForm {
            Toggle("Recordar vencimientos", isOn: Binding(get: { enabled }, set: { value in
                if !value { enabled = false; store.refreshReminders(); return }
                requesting = true
                Task {
                    do {
                        enabled = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        message = enabled ? "Recordatorios activados." : "No hay permiso de notificaciones. Podés habilitarlo desde Ajustes de iOS."
                        store.refreshReminders()
                    } catch { message = error.localizedDescription }
                    requesting = false
                }
            })).disabled(requesting)
            Text("Se programa un aviso a las 10:00 del día anterior al vencimiento. Se preparan las próximas fechas y se actualizan cada vez que abrís o guardás en la app.").font(.subheadline)
            Text("Configurá primero cierre y vencimiento de cada tarjeta. No son avisos del banco ni pagos automáticos.").font(.caption).foregroundStyle(Palette.muted)
            if !message.isEmpty { Text(message).font(.caption) }
        }.navigationTitle("Recordatorios").navigationBarTitleDisplayMode(.inline)
    }
}
