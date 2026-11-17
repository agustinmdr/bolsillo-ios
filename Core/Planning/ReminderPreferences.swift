import Foundation

struct ReminderPreferences: Codable, Equatable {
    static let key = "reminderPreferences.v1"
    var daysBefore = 1
    var hour = 10
    var minute = 0
    var fixedEnabled = false
    /// Preferencias de este dispositivo; no modifica el gasto ni su mes de resumen.
    var fixedDays: [String: Int] = [:]
    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: key), let preferences = try? JSONDecoder().decode(Self.self, from: data),
              (0...30).contains(preferences.daysBefore), (0...23).contains(preferences.hour), (0...59).contains(preferences.minute),
              preferences.fixedDays.values.allSatisfy({ (1...31).contains($0) }) else { return Self() }
        return preferences
    }
    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
struct FixedExpenseReminder: Identifiable {
    let expense: Expense
    let month: Month
    let dueDate: Date
    let fireDate: Date
    var id: String { "bolsillo.fixed.\(expense.id).\(month.id)" }
}
extension Ledger {
    func fixedReminderPlan(preferences: ReminderPreferences, now: Date = Date()) -> [FixedExpenseReminder] {
        guard preferences.fixedEnabled, (0...30).contains(preferences.daysBefore), (0...23).contains(preferences.hour), (0...59).contains(preferences.minute) else { return [] }
        let horizon = Calendar.current.date(byAdding: .month, value: 12, to: now)!
        var result: [FixedExpenseReminder] = []
        for expense in expenses where expense.recurring {
            guard let day = preferences.fixedDays[expense.id.uuidString], (1...31).contains(day) else { continue }
            for offset in 0...12 {
                let month = Month(now).adding(offset)
                guard expense.occurrence(in: month) != nil else { continue }
                let due = month.date(day: day)
                guard let fire = reminderDate(due: due, daysBefore: preferences.daysBefore, hour: preferences.hour, minute: preferences.minute), fire > now, fire <= horizon else { continue }
                result.append(FixedExpenseReminder(expense: expense, month: month, dueDate: due, fireDate: fire))
            }
        }
        return Array(result.sorted { $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate }.prefix(60))
    }
}
func reminderDate(due: Date, daysBefore: Int, hour: Int, minute: Int) -> Date? {
    guard let day = Calendar.current.date(byAdding: .day, value: -daysBefore, to: due) else { return nil }
    return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)
}
