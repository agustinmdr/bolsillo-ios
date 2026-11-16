import Foundation
import CryptoKit

enum CloudDecision: Equatable { case unchanged, upload, download, conflict }
enum CloudSyncRules {
    static func digest(_ ledger: Ledger) throws -> String {
        SHA256.hash(data: try LedgerStorage.data(ledger)).map { String(format: "%02x", $0) }.joined()
    }
    static func decide(local: String, remote: String?, base: String?, revision: Int64, knownRevision: Int64) -> CloudDecision {
        if local == remote { return .unchanged }
        if revision < knownRevision { return .conflict }
        guard let remote else { return knownRevision == 0 ? .upload : .conflict }
        guard let base else { return .conflict }
        if local == base { return .download }
        if remote == base { return .upload }
        return .conflict
    }
    static func endpoint(_ value: String) throws -> URL {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, url.path.isEmpty || url.path == "/" else { throw CloudError.invalidEndpoint }
        return url
    }
}
struct CloudEnvelope: Decodable {
    let revision: Int64
    let ledger: Ledger?
    func validate() throws {
        guard (0...9_007_199_254_740_991).contains(revision), ledger != nil || revision == 0 else { throw CloudError.invalidResponse }
        try ledger?.validate()
    }
}
enum CloudError: LocalizedError {
    case invalidEndpoint, invalidResponse, unauthorized, conflict, unavailable, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "Ingresá la dirección HTTPS de tu API, sin rutas ni contraseñas."
        case .invalidResponse: "El servidor devolvió datos incompatibles. Se conserva tu copia local."
        case .unauthorized: "La clave de sincronización no es válida. Revisá la configuración."
        case .conflict: "Hay cambios en la nube que necesitan revisión."
        case .unavailable: "No se pudo contactar la nube. Tus cambios siguen guardados en este dispositivo."
        case .tooLarge: "Los datos superan el tamaño permitido para sincronizar."
        }
    }
}
/// Evita reenviar la clave ante redirecciones a otro servidor.
private final class CloudRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct CloudClient {
    let endpoint: URL
    let token: String
    private let session: URLSession
    init(endpoint: URL, token: String, session: URLSession? = nil) {
        self.endpoint = endpoint; self.token = token
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 90; config.timeoutIntervalForResource = 100
        config.urlCache = nil; config.httpCookieStorage = nil
        self.session = session ?? URLSession(configuration: config, delegate: CloudRedirectGuard(), delegateQueue: nil)
    }
    func read() async throws -> CloudEnvelope {
        let result = try JSONDecoder().decode(CloudEnvelope.self, from: await request(method: "GET"))
        try result.validate(); return result
    }
    func write(_ ledger: Ledger, baseRevision: Int64) async throws -> Int64 {
        struct Body: Encodable { let baseRevision: Int64; let ledger: Ledger }
        struct Ack: Decodable { let revision: Int64 }
        try ledger.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let body = try encoder.encode(Body(baseRevision: baseRevision, ledger: ledger))
        guard body.count <= 8*1024*1024 else { throw CloudError.tooLarge }
        let result = try JSONDecoder().decode(Ack.self, from: await request(method: "PUT", body: body))
        guard result.revision > 0, result.revision <= 9_007_199_254_740_991 else { throw CloudError.invalidResponse }
        return result.revision
    }
    private func request(method: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: endpoint.appendingPathComponent("v1/ledger"))
        request.httpMethod = method; request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw CloudError.unauthorized
        case 409: throw CloudError.conflict
        case 413: throw CloudError.tooLarge
        default: throw CloudError.unavailable
        }
        guard data.count <= 8*1024*1024 else { throw CloudError.tooLarge }
        return data
    }
}
