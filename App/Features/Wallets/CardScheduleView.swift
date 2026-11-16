import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct CardScheduleView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let walletID: UUID
    @State private var enabled = false
    @State private var closing = 20
    @State private var due = 5
    @State private var offset = 1
    private var valid: Bool {
        !enabled || (0..<12).allSatisfy { n in let m = Month().adding(n); return m.adding(offset).date(day: due) >= m.date(day: closing) }
    }
    var body: some View {
        BolsilloForm {
            Section {
                Toggle("Configurar cierre y vencimiento", isOn: $enabled)
                if enabled {
                    Stepper("Día de cierre: \(closing)", value: $closing, in: 1...31)
                    Stepper("Día de vencimiento: \(due)", value: $due, in: 1...31)
                    Picker("Vence en", selection: $offset) { Text("Mes del cierre").tag(0); Text("Mes siguiente").tag(1); Text("Dos meses después").tag(2) }
                }
            }
            Section {
                Text("Una compra hasta el día del cierre inclusive se propone para ese mes; después del cierre, para el siguiente. Podés elegir otro mes al cargar el gasto.")
                Text("Los días 29 a 31 se ajustan al último día disponible. Son fechas estimadas: verificá feriados y cambios del banco. Los gastos existentes no se mueven de mes.").font(.caption).foregroundStyle(Palette.muted)
                if !valid { Text("El vencimiento debe ser posterior o igual al cierre.").foregroundStyle(Palette.danger) }
            }
            Button("Guardar configuración") {
                store.commit { data in if let i = data.wallets.firstIndex(where: { $0.id == walletID }) { data.wallets[i].closingDay = enabled ? closing : nil; data.wallets[i].dueDay = enabled ? due : nil; data.wallets[i].dueMonthOffset = enabled ? offset : nil } }
                if store.error == nil { dismiss() }
            }.disabled(!valid)
        }.navigationTitle("Cierre y vencimiento").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let wallet = store.ledger.wallets.first(where: { $0.id == walletID }) { enabled = wallet.closingDay != nil; closing = wallet.closingDay ?? 20; due = wallet.dueDay ?? 5; offset = wallet.dueMonthOffset ?? 1 }
            }
    }
}
