import AppIntents
import Foundation

struct BolsilloWalletEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tarjeta de Bolsillo"
    static var defaultQuery = BolsilloWalletQuery()
    var id: UUID
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct BolsilloWalletQuery: EntityQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [BolsilloWalletEntity] {
        Store.shared.ledger.wallets.filter { identifiers.contains($0.id) }.map { BolsilloWalletEntity(id: $0.id, name: $0.displayName) }
    }
    @MainActor func suggestedEntities() async throws -> [BolsilloWalletEntity] {
        Store.shared.ledger.wallets.map { BolsilloWalletEntity(id: $0.id, name: $0.displayName) }
    }
}
enum CaptureCurrency: String, AppEnum {
    case ars, usd
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Moneda"
    static var caseDisplayRepresentations: [CaptureCurrency: DisplayRepresentation] = [.ars: "Pesos argentinos (ARS)", .usd: "Dólares (USD)"]
}
struct RecordWalletExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar pago de Wallet"
    static var description = IntentDescription("Registra un gasto desde la automatización de una tarjeta de Wallet. Requiere activar la captura en Ajustes de Bolsillo.")
    static var openAppWhenRun: Bool = false
    @Parameter(title: "Importe") var amount: Double?
    @Parameter(title: "Comercio") var merchant: String?
    @Parameter(title: "Tarjeta en Bolsillo") var wallet: BolsilloWalletEntity
    @Parameter(title: "Moneda", default: .ars) var currency: CaptureCurrency
    @Parameter(title: "Nombre de tarjeta en Wallet") var walletLabel: String?
    @Parameter(title: "Fecha de la operación") var transactionDate: Date?
    @Parameter(title: "Mes del resumen") var statementDate: Date?
    @Parameter(title: "Identificador único (opcional)") var eventID: String?
    static var parameterSummary: some ParameterSummary {
        Summary("Registrar \(\.$amount) en \(\.$merchant) con \(\.$wallet)") {
            \.$currency; \.$walletLabel; \.$transactionDate; \.$statementDate; \.$eventID
        }
    }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard UserDefaults.standard.bool(forKey: "walletCaptureEnabled") else { throw WalletIntentError.disabled }
        guard let amount, amount.isFinite, let decimalAmount = Decimal(string: String(amount), locale: Locale(identifier: "en_US_POSIX")) else { throw WalletCaptureError.missingAmount }
        guard let merchant else { throw WalletCaptureError.missingMerchant }
        let store = Store.shared
        guard !store.loadFailed else { throw WalletIntentError.unreadable }
        let capture = WalletCapture(amount: decimalAmount, merchant: merchant, currency: currency == .ars ? "ARS" : "USD", walletID: wallet.id, date: transactionDate ?? Date(), statementMonth: statementDate.map { Month($0) }, eventID: eventID, walletLabel: walletLabel)
        var next = store.ledger
        let inserted = try capture.apply(to: &next)
        guard inserted else { return .result(dialog: "Posible repetición: no se agregó otro gasto. Revisá Bolsillo; si eran dos compras distintas, cargá la segunda manualmente.") }
        guard store.persist(next) else { throw WalletIntentError.saveFailed }
        return .result(dialog: "Gasto guardado en Bolsillo como Mío y Sin categorizar. Revisá el mes de resumen y las cuotas si corresponde.")
    }
}
enum WalletIntentError: LocalizedError {
    case disabled, unreadable, saveFailed
    var errorDescription: String? {
        switch self {
        case .disabled: return "Activá la captura en Bolsillo → Ajustes → Apple Pay y Atajos."
        case .unreadable: return "No se pudo leer el archivo de Bolsillo. Abrí la app y revisá el error; no se modificaron los gastos."
        case .saveFailed: return "No se pudo guardar el gasto. Abrí Bolsillo y revisá el almacenamiento del dispositivo."
        }
    }
}

struct BolsilloAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecordWalletExpenseIntent(), phrases: ["Registrar un pago en \(.applicationName)"], shortTitle: "Pago de Wallet", systemImageName: "creditcard")
    }
}
