import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL
    @AppStorage("cardRemindersEnabled") private var enabled = false
    @State private var preferences = ReminderPreferences.load()
    @State private var requesting = false
    @State private var message = ""
    @State private var denied = false
    private var time: Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: preferences.hour, minute: preferences.minute, second: 0, of: Date()) ?? Date() }, set: { preferences.hour = Calendar.current.component(.hour, from: $0); preferences.minute = Calendar.current.component(.minute, from: $0) })
    }
    var body: some View {
        BolsilloForm {
            Section {
                Toggle("Vencimientos de tarjetas", isOn: Binding(get: { enabled }, set: { setEnabled($0, fixed: false) })).disabled(requesting)
                Toggle("Gastos fijos", isOn: Binding(get: { preferences.fixedEnabled }, set: { setEnabled($0, fixed: true) })).disabled(requesting)
            } header: { Text("Qué querés recordar") } footer: { Text("Los avisos no muestran importes. Configurá cierre y vencimiento en cada tarjeta; los resúmenes conciliados y pagados dejan de avisar.") }
            Section("Cuándo avisarte") {
                Picker("Anticipación", selection: $preferences.daysBefore) {
                    Text("El mismo día").tag(0)
                    ForEach(1...30, id: \.self) { days in Text(days == 1 ? "1 día antes" : "\(days) días antes").tag(days) }
                }.pickerStyle(.menu)
                DatePicker("Hora del aviso", selection: time, displayedComponents: .hourAndMinute)
            }
            if preferences.fixedEnabled {
                Section {
                    let fixed = store.ledger.expenses.filter(\.recurring).sorted { $0.title < $1.title }
                    if fixed.isEmpty { Text("Activá «Se repite cada mes» en un gasto para configurar su recordatorio.").foregroundStyle(Palette.muted) }
                    ForEach(fixed) { expense in
                        Picker(selection: Binding(get: { preferences.fixedDays[expense.id.uuidString] ?? 0 }, set: { day in if day == 0 { preferences.fixedDays.removeValue(forKey: expense.id.uuidString) } else { preferences.fixedDays[expense.id.uuidString] = day } })) {
                            Text("Sin aviso").tag(0)
                            ForEach(1...31, id: \.self) { day in Text("Día \(day)").tag(day) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.displayTitle)
                                Text(store.ledger.wallets.first { $0.id == expense.walletID }?.displayName ?? "Cuenta").font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }.pickerStyle(.menu)
                    }
                } header: { Text("Día de vencimiento de cada fijo") } footer: { Text("Si elegís 29, 30 o 31 y ese día no existe, se usa el último día del mes. Se respeta el inicio y fin del gasto. El aviso no marca el gasto como pagado.") }
            }
            Section {
                if requesting { ProgressView("Solicitando permiso…") }
                if !message.isEmpty { Text(message).font(.subheadline) }
                if let status = store.reminderStatus { Text(status).font(.caption).foregroundStyle(Palette.muted) }
                Button("Actualizar recordatorios") { store.refreshReminders() }
                if denied { Button("Abrir ajustes de iOS") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } } }
            } footer: { Text("Se preparan hasta 60 avisos futuros dentro de los próximos 12 meses y se renuevan al abrir o guardar. Las preferencias son de este dispositivo. iOS puede silenciarlos según tus ajustes de notificaciones y Concentración.") }
        }.navigationTitle("Recordatorios").navigationBarTitleDisplayMode(.inline)
            .task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                denied = settings.authorizationStatus == .denied
                store.refreshReminders()
            }
            .onChange(of: preferences) { _, value in value.save(); store.refreshReminders() }
    }
    private func setEnabled(_ value: Bool, fixed: Bool) {
        guard value else {
            if fixed { preferences.fixedEnabled = false } else { enabled = false }
            store.refreshReminders(); return
        }
        requesting = true
        Task { @MainActor in
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                if fixed { preferences.fixedEnabled = allowed } else { enabled = allowed }
                denied = !allowed; message = allowed ? "Recordatorios activados." : "Habilitá las notificaciones desde Ajustes de iOS."
                preferences.save(); store.refreshReminders()
            } catch { message = "No se pudo solicitar el permiso: \(error.localizedDescription)" }
            requesting = false
        }
    }
}
