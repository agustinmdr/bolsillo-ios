import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct CoupleClosingView: View {
    @Environment(Store.self) private var store
    @State private var showOpening = false
    @State private var openingAmount = ""
    @State private var openingFrom: Person = .mai
    @State private var openingDate = Date()
    @State private var confirming = false
    private var summary: CoupleSummary { store.ledger.coupleSummary(in: store.month, currency: store.currency) }
    private var closing: CoupleClosing? { store.ledger.ops.closings.first { $0.month == store.month && $0.currency == store.currency } }
    var body: some View {
        BolsilloList {
            Section { PeriodPicker() }
            Section("Liquidación del mes") {
                signedRow("Saldo anterior", cents: summary.opening)
                signedRow("Movimiento del mes", cents: summary.movement)
                signedRow("Saldo final", cents: summary.ending)
                Text("Un saldo positivo significa que te deben; uno negativo, que vos debés. El saldo anterior incluye meses previos y sus devoluciones, sin contar dos veces un cierre.").font(.caption).foregroundStyle(Palette.muted)
                ShareLink(item: store.ledger.coupleText(in: store.month, currency: store.currency)) { Label("Compartir liquidación", systemImage: "square.and.arrow.up") }
            }
            Section("Cierre") {
                if let closing {
                    Text(closing.matches(summary) ? "Cierre al día" : "Los gastos o devoluciones cambiaron desde el cierre").foregroundStyle(closing.matches(summary) ? Palette.accent : Palette.warning)
                    Text("Guardado el \(closing.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(Palette.muted)
                } else { Text("Todavía no guardaste el cierre de este mes.") }
                Button(closing == nil ? "Guardar cierre mensual" : "Actualizar cierre") { confirming = true }
                Text("El cierre guarda una foto de los tres saldos. El saldo acumulado se sigue calculando con los datos actuales; si algo cambia, se indica acá para que puedas actualizarlo.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Deudas anteriores a Bolsillo") {
                Button("Configurar saldo inicial") { openingDate = store.month.date; openingAmount = ""; showOpening = true }
                ForEach(store.ledger.ops.openings.filter { $0.currency == store.currency }.sorted { $0.month < $1.month }) { opening in
                    VStack(alignment: .leading) { Text("Antes de \(opening.month.label)"); Text(money(opening.cents, currency: opening.currency)).font(.caption).foregroundStyle(Palette.muted) }
                        .swipeActions { Button("Eliminar", role: .destructive) { store.commit { $0.ops.openings.removeAll { $0.id == opening.id } } } }
                }
                Text("Un saldo inicial reemplaza el arrastre de los meses anteriores a esa fecha. No lo cargues además como gasto o préstamo: lo sumarías dos veces.").font(.caption).foregroundStyle(Palette.muted)
            }
        }.navigationTitle("Liquidación compartida").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("¿Guardar el cierre de \(store.month.label)?", isPresented: $confirming, titleVisibility: .visible) { Button("Guardar cierre") { store.commit { $0.closeCoupleMonth(store.month, currency: store.currency) } } }
            .sheet(isPresented: $showOpening) {
                NavigationStack { BolsilloForm {
                    DatePicker("Saldo anterior al mes", selection: $openingDate, displayedComponents: .date)
                    Picker("Quién debe", selection: $openingFrom) { Text("Me deben").tag(Person.mai); Text("Yo debo").tag(Person.agus) }
                    TextField("Importe en \(store.currency)", text: $openingAmount).keyboardType(.decimalPad)
                    Text("Se conserva el historial. Para calcular desde este mes, el importe ingresado reemplaza las deudas y devoluciones de los meses anteriores.").font(.caption)
                }.navigationTitle("Saldo inicial").toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showOpening = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                        guard let cents = parseCents(openingAmount) else { return }
                        store.commit { data in data.ops.openings.removeAll { $0.month == Month(openingDate) && $0.currency == store.currency }; data.ops.openings.append(CoupleOpening(month: Month(openingDate), currency: store.currency, cents: openingFrom == .mai ? cents : -cents)) }
                        if store.error == nil { showOpening = false }
                    }.disabled(parseCents(openingAmount) == nil) }
                } }
            }
    }
    private func signedRow(_ title: String, cents: Int64) -> some View {
        HStack { Text(title); Spacer(); Text(money(cents, currency: store.currency)).fontWeight(.semibold).foregroundStyle(cents < 0 ? Palette.warning : Palette.accent) }
    }
}
