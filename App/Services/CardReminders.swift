import Foundation
import UserNotifications

enum CardReminders {
    @MainActor static func refresh(ledger: Ledger, enabled: Bool, preferences: ReminderPreferences) async -> String {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else { return "" }
        let owned = pending.filter { $0.identifier.hasPrefix("bolsillo.card.") || $0.identifier.hasPrefix("bolsillo.fixed.") }
        center.removePendingNotificationRequests(withIdentifiers: owned.map(\.identifier))
        guard enabled || preferences.fixedEnabled else { return "Recordatorios desactivados." }
        let settings = await center.notificationSettings()
        guard !Task.isCancelled else { return "" }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return "iOS no permite las notificaciones. Habilitalas desde Ajustes del dispositivo." }
        struct Planned {
            let id: String
            let title: String
            let body: String
            let fire: Date
        }
        var requests: [Planned] = []
        if enabled {
            requests += ledger.cardReminderPlan(daysBefore: preferences.daysBefore, hour: preferences.hour, minute: preferences.minute).map { reminder in
                Planned(id: reminder.id, title: "Vencimiento de \(reminder.walletName)", body: "El resumen de \(reminder.month.label) vence el \(reminder.dueDate.formatted(date: .abbreviated, time: .omitted)). Revisá el pago en Bolsillo.", fire: reminder.fireDate)
            }
        }
        requests += ledger.fixedReminderPlan(preferences: preferences).map { reminder in
            Planned(id: reminder.id, title: "Recordatorio de \(reminder.expense.displayTitle)", body: "Vence el \(reminder.dueDate.formatted(date: .abbreviated, time: .omitted)). Revisá este gasto fijo en Bolsillo.", fire: reminder.fireDate)
        }
        // El cupo es compartido: se respetan solicitudes de otras funcionalidades.
        let available = max(0, 60 - (pending.count-owned.count))
        let planned = requests.sorted { $0.fire == $1.fire ? $0.id < $1.id : $0.fire < $1.fire }.prefix(available)
        var scheduled = 0, failed = 0
        for reminder in planned {
            guard !Task.isCancelled else { return "" }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fire)
            let content = UNMutableNotificationContent()
            content.title = reminder.title; content.body = reminder.body; content.sound = .default
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do { try await center.add(request); scheduled += 1 } catch { failed += 1 }
        }
        if failed > 0 { return "\(scheduled) avisos programados; \(failed) no se pudieron programar. Volvé a intentarlo." }
        if scheduled == 0 { return "No hay avisos futuros para programar. Revisá los vencimientos y los días de tus gastos fijos." }
        return "\(scheduled) avisos programados. Se actualizan al abrir o guardar en la app."
    }
}
