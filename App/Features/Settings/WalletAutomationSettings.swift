import SwiftUI
import UniformTypeIdentifiers
import AppIntents

struct WalletAutomationSettings: View {
    @Environment(Store.self) private var store
    @AppStorage("walletCaptureEnabled") private var enabled = false
    var body: some View {
        BolsilloList {
            Section {
                Toggle("Permitir registrar pagos desde Atajos", isOn: $enabled)
                Text("Esto habilita la acción de Bolsillo. La automatización de Wallet se configura por separado en Atajos, en este iPhone.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("1. Abrí la app Atajos") {
                ShortcutsLink()
                Text("Buscá la acción ‘Registrar pago de Wallet’ de Bolsillo. Si no aparece, abrí Bolsillo una vez después de instalar esta actualización.").font(.subheadline)
            }
            Section("2. Creá una automatización por tarjeta") {
                Text("En Atajos → Automatización, creá una nueva. Elegí Wallet o Transacción, según tu versión de iOS, y seleccioná una tarjeta. Configurala para ejecutarse inmediatamente si esa opción está disponible.")
                Text("Agregá directamente la acción ‘Registrar pago de Wallet’ de Bolsillo. Elegí en ‘Tarjeta en Bolsillo’ la cuenta que corresponde a esa tarjeta física.")
                Text("Repetí estos pasos para cada tarjeta. No se intenta adivinar la cuenta por el nombre que entrega Wallet.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("3. Vinculá los datos de entrada") {
                LabeledContent("Importe", value: "Entrada de transacción → Amount")
                LabeledContent("Comercio", value: "Entrada de transacción → Merchant")
                LabeledContent("Tarjeta en Bolsillo", value: "Elegir una de tus cuentas")
                LabeledContent("Moneda", value: "ARS o USD, explícitamente")
                Text("Tocá cada variable de entrada para seleccionar su propiedad. Los nombres pueden aparecer traducidos como Importe y Comercio. Si Wallet no entrega un importe numérico o un comercio, la acción muestra un error y no guarda un gasto incompleto.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Opcionales") {
                Text("Nombre de tarjeta en Wallet: podés vincular Card or Pass como referencia. Fecha de la operación: si no la pasás, se usa la hora de ejecución. Mes del resumen: si lo dejás vacío, se sugiere según el cierre configurado para esa tarjeta. Sin configuración se usa el mes de la operación. Podés enviar un mes explícito para reemplazar esa sugerencia.")
                Text("Identificador único: usalo solo si tu origen proporciona un ID estable por operación. No uses el nombre del comercio ni el de la tarjeta como identificador.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("4. Probalo antes de automatizar") {
                Text("Ejecutá la acción manualmente en Atajos con un importe pequeño y un comercio de prueba. Verificá el registro en Gastos y eliminá esa prueba. Después verificá un pago real de Wallet con tu tarjeta.")
                Text("Los registros quedan como Mío, Sin categorizar y con etiquetas ‘Apple Pay’ y ‘Por revisar’. No se detectan cuotas automáticamente. El pagador es el titular configurado para la cuenta.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Repeticiones y alcance") {
                Text("Con ID estable se omiten repeticiones de ese ID. Sin ID, se avisa como posible repetición si hay un registro de Apple Pay igual en la misma cuenta, moneda, comercio e importe, dentro de 10 segundos. Dos compras reales iguales en ese intervalo requieren revisar y cargar la segunda manualmente.").font(.caption)
                Text("No hay conexión directa al banco ni lectura del historial de Wallet. La captura depende de que iOS dispare la automatización y entregue los datos. Si falla, no se recuperan pagos pasados automáticamente.").font(.caption).foregroundStyle(Palette.muted)
            }
            Section("Últimos pagos recibidos") {
                let recent = store.ledger.expenses.filter { $0.sourceKey?.hasPrefix("apple-pay-") == true }.sorted { $0.date > $1.date }.prefix(5)
                if recent.isEmpty { Text("Todavía no recibiste pagos desde Atajos.").foregroundStyle(Palette.muted) }
                ForEach(Array(recent)) { expense in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(expense.title).font(.subheadline.weight(.semibold))
                        Text("\(money(expense.cents, currency: expense.currency)) · \(expense.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
        }.navigationTitle("Apple Pay y Atajos").navigationBarTitleDisplayMode(.inline)
    }
}
