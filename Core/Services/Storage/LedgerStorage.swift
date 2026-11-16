import Foundation

struct LedgerStorage {
    let folder: URL
    var fileURL: URL { folder.appendingPathComponent("ledger.json") }
    var backupsURL: URL { folder.appendingPathComponent("Backups", isDirectory: true) }
    let retention = 30
    func load() throws -> Ledger? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decode(Data(contentsOf: fileURL))
    }
    func decode(_ data: Data) throws -> Ledger {
        let ledger = try JSONDecoder().decode(Ledger.self, from: data)
        try ledger.validate(); return ledger
    }
    static func data(_ ledger: Ledger) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(ledger)
    }
    /// Devuelve un aviso si el último respaldo falla después de guardar; nunca
    /// presenta un cambio guardado como si se hubiese perdido.
    func save(_ ledger: Ledger, restoring: Bool = false) throws -> String? {
        try ledger.validate()
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        if manager.fileExists(atPath: fileURL.path) {
            let old = try Data(contentsOf: fileURL)
            var valid = true
            do { _ = try decode(old) }
            catch {
                guard restoring else { throw error }
                try old.write(to: folder.appendingPathComponent("Recovery-\(UUID().uuidString).bin"), options: .atomic)
                valid = false
            }
            if valid { _ = try snapshot(old) }
        }
        let data = try Self.data(ledger)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        do { _ = try snapshot(data); return nil }
        catch { return "Los cambios se guardaron, pero falló el último respaldo local: \(error.localizedDescription)" }
    }
    @discardableResult func snapshot(_ data: Data) throws -> URL {
        _ = try decode(data)
        return try Self.snapshot(data, in: backupsURL, retention: retention)
    }
    @discardableResult static func snapshot(_ data: Data, in destination: URL, retention: Int = 30) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        let existing = try snapshots(in: destination)
        if let latest = existing.first, try Data(contentsOf: latest) == data { return latest }
        let format = DateFormatter(); format.locale = Locale(identifier: "en_US_POSIX"); format.timeZone = TimeZone(secondsFromGMT: 0); format.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let url = destination.appendingPathComponent("Bolsillo-\(format.string(from: Date()))-\(UUID().uuidString).json")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        let ordered = try snapshots(in: destination)
        for stale in ordered.dropFirst(max(retention, 1)) { try manager.removeItem(at: stale) }
        return url
    }
    static func snapshots(in folder: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]).filter {
            $0.lastPathComponent.range(of: #"^Bolsillo-\d{8}-\d{6}-\d{3}-[A-Fa-f0-9-]{36}\.json$"#, options: .regularExpression) != nil
        }.sorted {
            let l = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l == r ? $0.lastPathComponent > $1.lastPathComponent : l > r
        }
    }
}
