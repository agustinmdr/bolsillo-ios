import Foundation

final class MockProtocol: URLProtocol {
    static var response: (Int, Data) = (200, Data())
    static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let (status, data) = Self.response
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct Checks {
    static func main() async throws {
        var count = 0
        func check(_ condition: Bool) { precondition(condition); count += 1 }
        check(CloudSyncRules.decide(local: "a", remote: nil, base: nil, revision: 0, knownRevision: 0) == .upload)
        check(CloudSyncRules.decide(local: "a", remote: "a", base: nil, revision: 2, knownRevision: 0) == .unchanged)
        check(CloudSyncRules.decide(local: "a", remote: "b", base: nil, revision: 2, knownRevision: 0) == .conflict)
        check(CloudSyncRules.decide(local: "a", remote: "b", base: "a", revision: 2, knownRevision: 1) == .download)
        check(CloudSyncRules.decide(local: "b", remote: "a", base: "a", revision: 1, knownRevision: 1) == .upload)
        check(CloudSyncRules.decide(local: "b", remote: "c", base: "a", revision: 2, knownRevision: 1) == .conflict)
        check(CloudSyncRules.decide(local: "a", remote: nil, base: "a", revision: 0, knownRevision: 3) == .conflict)
        check(CloudSyncRules.decide(local: "a", remote: "b", base: "a", revision: 1, knownRevision: 3) == .conflict)
        for value in ["http://api.example.com", "https://user:password@api.example.com", "https://api.example.com/path", "https://api.example.com?token=private", "https://api.example.com#x"] {
            do { _ = try CloudSyncRules.endpoint(value); fatalError("Endpoint inválido aceptado") } catch { count += 1 }
        }
        let endpoint = try CloudSyncRules.endpoint("https://api.example.com")
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MockProtocol.self]
        let token = String(repeating: "x", count: 48)
        let client = CloudClient(endpoint: endpoint, token: token, session: URLSession(configuration: config))
        MockProtocol.response = (200, Data("{\"revision\":0,\"ledger\":null}".utf8))
        let empty = try await client.read(); check(empty.revision == 0 && empty.ledger == nil)
        check(MockProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
        check(MockProtocol.lastRequest?.url?.path == "/v1/ledger")
        for (code, expected) in [(401, "auth"), (409, "conflict"), (503, "unavailable")] {
            MockProtocol.response = (code, Data("{}".utf8))
            do { _ = try await client.read(); fatalError("Error HTTP no propagado") }
            catch CloudError.unauthorized { check(expected == "auth") }
            catch CloudError.conflict { check(expected == "conflict") }
            catch CloudError.unavailable { check(expected == "unavailable") }
        }
        MockProtocol.response = (200, Data("{\"revision\":2,\"ledger\":null}".utf8))
        do { _ = try await client.read(); fatalError("Estado inválido aceptado") } catch { count += 1 }
        let ledger = Ledger(), before = try CloudSyncRules.digest(ledger)
        MockProtocol.response = (200, Data("{\"revision\":1}".utf8))
        let revision = try await client.write(ledger, baseRevision: 0)
        check(revision == 1); check(before == (try CloudSyncRules.digest(ledger)))
        check(MockProtocol.lastRequest?.httpMethod == "PUT")
        MockProtocol.response = (200, Data("{\"revision\":-1}".utf8))
        do { _ = try await client.write(ledger, baseRevision: 0); fatalError("Revisión negativa aceptada") } catch { count += 1 }
        if CommandLine.arguments.count > 1 {
            struct LiveConfig: Decodable { let endpoint: String; let token: String }
            let config = try JSONDecoder().decode(LiveConfig.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            let live = CloudClient(endpoint: try CloudSyncRules.endpoint(config.endpoint), token: config.token)
            let result = try await live.read()
            check(result.revision >= 0)
            print("Cliente Swift conectado a la API real por HTTPS; lectura validada sin escribir movimientos.")
        }
        print("\(count) comprobaciones de sincronización correctas.")
    }
}
