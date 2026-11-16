import Foundation
import UserNotifications

enum CardReminders {
    @MainActor static func refresh(ledger: Ledger, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("bolsillo.card.") }.map(\.identifier))
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard !Task.isCancelled, settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for reminder in ledger.cardReminderPlan() {
                guard !Task.isCancelled else { return }
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
                let content = UNMutableNotificationContent()
                content.title = "Vence \(reminder.walletName)"
                content.body = "Mañana vence el resumen de \(reminder.month.label). Revisá el importe y el pago en Bolsillo."
                content.sound = .default
                let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                try? await center.add(request)
        }
    }
}
