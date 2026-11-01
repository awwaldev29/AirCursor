import AirCursorKit
import Foundation
import Network
import Observation

/// Finds AirCursor Macs on the local network over Bonjour, so nobody has to type an IP.
@MainActor
@Observable
final class MacBrowser {
    struct FoundMac: Identifiable, Hashable {
        let name: String
        let endpoint: NWEndpoint
        var id: String { name }
    }

    private(set) var macs: [FoundMac] = []
    @ObservationIgnored private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: AirCursorProtocol.bonjourType, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let macs = results.compactMap { result -> FoundMac? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                return FoundMac(name: name, endpoint: result.endpoint)
            }
            Task { @MainActor in self?.macs = macs.sorted { $0.name < $1.name } }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    /// Resolves a Bonjour service to "ip:port" by briefly connecting to it over IPv4.
    nonisolated static func resolve(_ endpoint: NWEndpoint) async throws -> String {
        let parameters = NWParameters.tcp
        if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let connection = NWConnection(to: endpoint, using: parameters)
        let once = ResumeOnce()

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if case .hostPort(let host, let port) = connection.currentPath?.remoteEndpoint,
                       case .ipv4(let address) = host {
                        let ip = "\(address)".split(separator: "%").first.map(String.init) ?? "\(address)"
                        once.run { continuation.resume(returning: "\(ip):\(port.rawValue)") }
                    } else {
                        once.run { continuation.resume(throwing: URLError(.cannotFindHost)) }
                    }
                    connection.cancel()
                case .failed(let error), .waiting(let error):
                    once.run { continuation.resume(throwing: error) }
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }
}

/// Guards a continuation against being resumed twice from NWConnection state callbacks.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        let shouldRun = lock.withLock {
            defer { done = true }
            return !done
        }
        if shouldRun { body() }
    }
}
