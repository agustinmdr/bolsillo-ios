import SwiftUI
import WidgetKit
import UniformTypeIdentifiers

@MainActor @Observable final class Store {
    static let shared = Store()
    var ledger = Ledger()
    var error: String?
    var loadFailed = false
    var month = Month()
    var currency = "ARS"
    var showAdd = false
    private(set) var deletingExpenseID: UUID?
    var reviewUndo: BulkUndo?
    var reminderStatus: String?
    var backupNotice: String?
    var backupURLs: [URL] = []
    var migrationCandidates: [MigrationCandidate] = []
    let cloud = CloudSyncManager()
    private var starting = true
    private let storage: LedgerStorage
    private var reminderTask: Task<Void, Never>?
    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storage = LedgerStorage(folder: base.appendingPathComponent("Bolsillo", isDirectory: true))
        do {
            if let stored = try storage.load() { ledger = stored }
        } catch { self.error = "No se pudieron leer los datos. No se sobrescribirá el archivo. \(error.localizedDescription)"; loadFailed = true }
        if !loadFailed {
            importBundledHistoryIfNeeded(); addMissingCategories(); addExpandedCategories()
            var next = ledger
            if next.assignCategoryColors() { persist(next) }
            importSupplement()
            applyConfirmedSetup()
            var cleaned = ledger
            if cleaned.cleanImportedWallets() { persist(cleaned) }
        }
        refreshBackupList()
        starting = false
        cloud.schedule(store: self)
    }
    var charges: [Charge] { ledger.charges(in: month, currency: currency) }
    private func applyConfirmedSetup() {
        do {
            guard let url = Bundle.main.url(forResource: "private-setup", withExtension: "json") else { return }
            let setups = try JSONDecoder().decode([ConfirmedLedgerSetup].self, from: Data(contentsOf: url))
            for setup in setups {
                let key = "migration.\(setup.id)"
                if ledger.ops.completedMigrations.contains(setup.id) { UserDefaults.standard.set(true, forKey: key); continue }
                guard !UserDefaults.standard.bool(forKey: key) else { continue }
                var next = ledger
                if next.applyConfirmedSetup(setup), persist(next) { UserDefaults.standard.set(true, forKey: key) }
            }
        } catch { self.error = "No se pudo leer la configuración local. \(error.localizedDescription)" }
    }
    private func addExpandedCategories() {
        let key = "categories.expanded.v1.completed"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        var next = ledger
        let added = next.addExpandedCategories()
        if added == 0 || persist(next) { UserDefaults.standard.set(true, forKey: key) }
    }
    private func addMissingCategories() {
        let key = "categories.technology-auto.v1.completed"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let additions = Category.defaults.filter { candidate in
            ["Tecnología", "Auto"].contains(candidate.name) && !ledger.categories.contains { $0.name.localizedCaseInsensitiveCompare(candidate.name) == .orderedSame }
        }
        var next = ledger
        next.categories.append(contentsOf: additions)
        if additions.isEmpty || persist(next) { UserDefaults.standard.set(true, forKey: key) }
    }
    func commit(_ change: (inout Ledger) -> Void) {
        guard !loadFailed else { error = "Restaurá un respaldo válido antes de modificar datos."; return }
        var next = ledger; change(&next)
        persist(next)
    }
    @discardableResult func persist(_ next: Ledger, restoring: Bool = false, fromCloud: Bool = false) -> Bool {
        do {
            var next = next
            next.assignCategoryColors()
            try next.validate()
            backupNotice = try storage.save(next, restoring: restoring)
            ledger = next; if restoring { loadFailed = false; reviewUndo = nil }; updateWidget()
            refreshBackupList(); writeExternalBackup(); refreshReminders()
            if !starting && !fromCloud { cloud.schedule(store: self) }
            return true
        } catch { self.error = "No se guardó el cambio: \(error.localizedDescription)"; return false }
    }
    private func importSupplement() {
        do {
            guard let url = Bundle.main.url(forResource: "complemento-planilla", withExtension: "json") else { return }
            migrationCandidates = try JSONDecoder().decode([MigrationCandidate].self, from: Data(contentsOf: url))
            let key = "migration.supplement-v1.completed"
            if ledger.ops.completedMigrations.contains("supplement-v1") { UserDefaults.standard.set(true, forKey: key); return }
            guard !UserDefaults.standard.bool(forKey: key) else { return }
            var next = ledger
            next.importSafeSupplement(migrationCandidates)
            next.ops.completedMigrations.append("supplement-v1")
            if persist(next) { UserDefaults.standard.set(true, forKey: key) }
        } catch { self.error = "No se pudo leer el complemento de la planilla: \(error.localizedDescription)" }
    }
    func applyBulk(ids: Set<UUID>, change: BulkChange) {
        guard !loadFailed else { return }
        var next = ledger
        let undo = next.applyBulk(ids: ids, change: change)
        if persist(next) { reviewUndo = undo }
    }
    func undoReview() -> Int {
        guard let undo = reviewUndo, !loadFailed else { return 0 }
        var next = ledger; let count = next.undoBulk(undo)
        if persist(next) { reviewUndo = nil; return count }; return 0
    }
    @discardableResult func deleteExpense(_ id: UUID) async -> Bool {
        guard deletingExpenseID == nil else { return false }
        guard !loadFailed else { error = "Restaurá un respaldo válido antes de modificar datos."; return false }
        guard ledger.expenses.contains(where: { $0.id == id }) || ledger.ops.adjustments.contains(where: { $0.id == id }) else { return false }
        deletingExpenseID = id
        defer { deletingExpenseID = nil }
        // Dejar que la interfaz dibuje el indicador antes del guardado síncrono.
        do { try await Task.sleep(for: .milliseconds(80)) } catch { return false }
        // Leer la versión actual después de la espera, para conservar cambios concurrentes.
        var next = ledger
        next.expenses.removeAll { $0.id == id }
        next.ops.adjustments.removeAll { $0.id == id }
        let saved = persist(next)
        // Mantener el bloqueo un instante para absorber toques que quedaron en cola.
        try? await Task.sleep(for: .milliseconds(200))
        return saved
    }
    func refreshBackupList() { backupURLs = (try? LedgerStorage.snapshots(in: storage.backupsURL)) ?? [] }
    func createBackupNow() {
        guard !loadFailed else { error = "Restaurá primero un archivo válido para crear nuevos respaldos."; return }
        do { _ = try storage.snapshot(LedgerStorage.data(ledger)); refreshBackupList(); writeExternalBackup(); if backupNotice == nil { backupNotice = "Respaldo local actualizado." } }
        catch { self.error = error.localizedDescription }
    }
    func restoreBackup(_ url: URL) {
        do { let next = try storage.decode(Data(contentsOf: url)); persist(next, restoring: true) }
        catch { self.error = "No se restauró el respaldo: \(error.localizedDescription)" }
    }
    func setExternalBackupFolder(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            _ = try LedgerStorage.snapshot(try LedgerStorage.data(ledger), in: url.appendingPathComponent("BolsilloBackups", isDirectory: true))
            UserDefaults.standard.set(bookmark, forKey: "backupFolderBookmark")
            UserDefaults.standard.set(url.lastPathComponent, forKey: "backupFolderName")
            backupNotice = "Respaldo externo creado en \(url.lastPathComponent)."
        } catch { self.error = "No se pudo habilitar el respaldo en esa carpeta: \(error.localizedDescription)" }
    }
    func disableExternalBackup() {
        UserDefaults.standard.removeObject(forKey: "backupFolderBookmark")
        UserDefaults.standard.removeObject(forKey: "backupFolderName")
        backupNotice = "Respaldo externo desactivado. Se conservan los respaldos existentes."
    }
    private func writeExternalBackup() {
        guard let bookmark = UserDefaults.standard.data(forKey: "backupFolderBookmark") else { return }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            _ = try LedgerStorage.snapshot(try LedgerStorage.data(ledger), in: url.appendingPathComponent("BolsilloBackups", isDirectory: true))
            if stale { UserDefaults.standard.set(try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil), forKey: "backupFolderBookmark") }
        } catch { backupNotice = "Los datos se guardaron localmente, pero falló la copia externa. Volvé a elegir su carpeta. \(error.localizedDescription)" }
    }
    func refreshReminders() {
        let previous = reminderTask
        previous?.cancel()
        let data = ledger; let enabled = UserDefaults.standard.bool(forKey: "cardRemindersEnabled")
        let preferences = ReminderPreferences.load()
        reminderTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let status = await CardReminders.refresh(ledger: data, enabled: enabled, preferences: preferences)
            if !Task.isCancelled { self.reminderStatus = status }
        }
    }
    private func importBundledHistoryIfNeeded() {
        let key = "import.planilla2026.cards.v1.completed"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            guard let url = Bundle.main.url(forResource: "historico-revisar", withExtension: "csv") else {
                throw FinanceError.csv("No se encontró el histórico de tu planilla.")
            }
            let text = try String(contentsOf: url, encoding: .utf8)
            let additions = try CSV.preview(text, ledger: ledger)
            var next = ledger
            next.expenses.append(contentsOf: additions)
            // El respaldo anterior se conserva; solo se marca tras guardar con éxito.
            if additions.isEmpty || persist(next) {
                UserDefaults.standard.set(true, forKey: key)
            }
        } catch { self.error = "No se pudo cargar la planilla: \(error.localizedDescription)" }
    }
    func updateWidget() {
        let now = Month()
        let total = ledger.charges(in: now, currency: "ARS").reduce(Int64(0)) { $0 + $1.cents }
        let defaults = UserDefaults(suiteName: "group.com.agustin.bolsillo")
        defaults?.set(try? JSONEncoder().encode(ledger.expenses), forKey: "expenses")
        defaults?.set(try? JSONEncoder().encode(ledger.ops.adjustments), forKey: "adjustments")
        defaults?.set(total, forKey: "monthTotal"); defaults?.set(now.label, forKey: "monthLabel")
        WidgetCenter.shared.reloadAllTimelines()
    }
    func exportURL(backup: Bool) -> URL? {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(backup ? "Bolsillo-respaldo.json" : "Bolsillo-\(month.id)-\(currency).csv")
            let data = backup ? try JSONEncoder().encode(ledger) : Data(CSV.export(charges, ledger: ledger).utf8)
            try data.write(to: url, options: .atomic); return url
        } catch { self.error = error.localizedDescription; return nil }
    }
    func exportExcel() async -> URL? {
        let snapshot = ledger, period = month
        do {
            return try await Task.detached(priority: .userInitiated) {
                let data = try ExcelReport.data(ledger: snapshot, month: period)
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Reportes/\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent("Bolsillo-\(period.id).xlsx")
                try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
                return url
            }.value
        } catch { self.error = "No se pudo generar el Excel: \(error.localizedDescription)"; return nil }
    }
}
