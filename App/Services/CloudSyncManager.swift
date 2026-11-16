import Foundation
import Observation
import Security

private struct CloudConnection: Codable {
    var endpoint: String
    var token: String
    var revision: Int64 = 0
    var digest: String?
    var lastSync: Date?
}
private enum CloudKeychain {
    static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.agustin.bolsillo.cloud", kSecAttrAccount as String: "personal-ledger"]
    static func read() throws -> CloudConnection? {
        var request = query; request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CloudError.unavailable }
        return try JSONDecoder().decode(CloudConnection.self, from: data)
    }
    static func save(_ connection: CloudConnection) throws {
        let attributes: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(connection), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) }
        guard status == errSecSuccess else { throw CloudError.unavailable }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CloudError.unavailable }
    }
}

@MainActor @Observable final class CloudSyncManager {
    var enabled = false
    var endpoint = ""
    var syncing = false
    var message = "Sincronización sin configurar"
    var lastSync: Date?
    var conflict: CloudEnvelope?
    @ObservationIgnored private var connection: CloudConnection?
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var rerunWhenDone = false
    @ObservationIgnored private var retryCredentialLoad = false
    init() {
        do {
            connection = try CloudKeychain.read()
            if let connection { enabled = true; endpoint = connection.endpoint; lastSync = connection.lastSync; message = "Lista para sincronizar" }
        } catch { retryCredentialLoad = true; message = "No se pudo abrir la configuración privada de sincronización. Volvé a abrir la app con el dispositivo desbloqueado." }
    }
    func connect(endpoint: String, token: String, store: Store) async {
        guard !syncing else { return }
        do {
            let url = try CloudSyncRules.endpoint(endpoint), key = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (32...512).contains(key.utf8.count), key.utf8.allSatisfy({ (33...126).contains($0) }) else { message = "Ingresá la clave privada de tu API (al menos 32 caracteres)."; return }
            let config = CloudConnection(endpoint: url.absoluteString, token: key)
            try CloudKeychain.save(config)
            generation = UUID(); pending?.cancel(); retryCredentialLoad = false; connection = config; self.endpoint = config.endpoint; enabled = true; conflict = nil; lastSync = nil
            await synchronize(store: store)
        } catch { message = error.localizedDescription }
    }
    func disconnect() {
        guard !syncing else { return }
        do {
            try CloudKeychain.remove(); generation = UUID(); pending?.cancel(); retryCredentialLoad = false; connection = nil; enabled = false; conflict = nil; lastSync = nil; endpoint = ""
            message = "Desconectada. Los datos locales y la copia en la nube se conservan."
        } catch { message = "No se pudo quitar la configuración del llavero." }
    }
    func schedule(store: Store) {
        if retryCredentialLoad {
            do {
                connection = try CloudKeychain.read(); retryCredentialLoad = false
                if let connection { enabled = true; endpoint = connection.endpoint; lastSync = connection.lastSync; message = "Lista para sincronizar" }
            } catch { return }
        }
        guard enabled, conflict == nil else { return }
        if syncing { rerunWhenDone = true; return }
        pending?.cancel()
        pending = Task { [weak self, weak store] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, let store else { return }
            await self.synchronize(store: store)
        }
    }
    func synchronize(store: Store) async {
        guard let config = connection, !syncing else { return }
        let run = generation
        syncing = true; message = "Sincronizando…"
        var changedWhileUploading = false
        defer { let again = rerunWhenDone; rerunWhenDone = false; syncing = false; if changedWhileUploading || again { schedule(store: store) } }
        do {
            let client = CloudClient(endpoint: try CloudSyncRules.endpoint(config.endpoint), token: config.token)
            let remote = try await client.read()
            guard run == generation else { return }
            if store.loadFailed {
                if remote.ledger != nil { conflict = remote; message = "La copia local no se pudo leer. Podés recuperar la versión de la nube." }
                else { message = "No hay una copia válida en la nube. Restaurá un respaldo local." }
                return
            }
            let snapshot = store.ledger, localDigest = try CloudSyncRules.digest(snapshot)
            let remoteDigest = try remote.ledger.map(CloudSyncRules.digest)
            switch CloudSyncRules.decide(local: localDigest, remote: remoteDigest, base: config.digest, revision: remote.revision, knownRevision: config.revision) {
            case .unchanged:
                try acknowledge(revision: remote.revision, digest: localDigest)
            case .upload:
                let revision = try await client.write(snapshot, baseRevision: remote.revision)
                guard run == generation else { return }
                try acknowledge(revision: revision, digest: localDigest)
                changedWhileUploading = try CloudSyncRules.digest(store.ledger) != localDigest
                if changedWhileUploading { message = "Últimos cambios pendientes de subir" }
            case .download:
                guard let ledger = remote.ledger, let remoteDigest else { throw CloudError.invalidResponse }
                guard store.persist(ledger, restoring: true, fromCloud: true) else { message = "No se pudo guardar la copia de la nube. Se conserva la versión local."; return }
                try acknowledge(revision: remote.revision, digest: remoteDigest)
                changedWhileUploading = try CloudSyncRules.digest(store.ledger) != remoteDigest
            case .conflict:
                conflict = remote; message = config.digest == nil ? "Hay datos en ambos lugares. Elegí qué copia conservar." : "Hay cambios en ambos dispositivos. Revisá las copias antes de continuar."
            }
        } catch CloudError.conflict {
            message = "La nube cambió durante el envío. Revisá las versiones y volvé a sincronizar."
            // No reintentar la escritura con una revisión nueva sin comparar ambas copias.
        } catch { message = "\(error is URLError ? CloudError.unavailable.localizedDescription : error.localizedDescription)" }
    }
    func useCloud(store: Store) {
        guard !syncing, let remote = conflict, let ledger = remote.ledger else { return }
        do {
            let digest = try CloudSyncRules.digest(ledger)
            guard store.persist(ledger, restoring: true, fromCloud: true) else { message = "No se pudo guardar. Se conserva la copia local."; return }
            try acknowledge(revision: remote.revision, digest: digest); conflict = nil
            if try CloudSyncRules.digest(store.ledger) != digest { schedule(store: store) }
        } catch { message = error.localizedDescription }
    }
    func useLocal(store: Store) async {
        guard !syncing, !store.loadFailed, let remote = conflict, let config = connection else { return }
        let run = generation
        syncing = true; message = "Guardando tu copia en la nube…"
        var changed = false
        defer { let again = rerunWhenDone; rerunWhenDone = false; syncing = false; if changed || again { schedule(store: store) } }
        do {
            store.createBackupNow()
            guard store.error == nil else { message = "No se pudo proteger la copia local antes de continuar."; return }
            let snapshot = store.ledger, digest = try CloudSyncRules.digest(snapshot)
            let client = CloudClient(endpoint: try CloudSyncRules.endpoint(config.endpoint), token: config.token)
            let revision = try await client.write(snapshot, baseRevision: remote.revision)
            guard run == generation else { return }
            try acknowledge(revision: revision, digest: digest); conflict = nil
            changed = try CloudSyncRules.digest(store.ledger) != digest
        } catch CloudError.conflict {
            conflict = nil; message = "La nube volvió a cambiar. Sincronizá de nuevo para revisar la copia actual." 
        } catch { message = error is URLError ? CloudError.unavailable.localizedDescription : error.localizedDescription }
    }
    private func acknowledge(revision: Int64, digest: String) throws {
        guard var config = connection else { return }
        config.revision = revision; config.digest = digest; config.lastSync = Date()
        try CloudKeychain.save(config)
        connection = config; lastSync = config.lastSync; conflict = nil; message = "Todo sincronizado"
    }
}
