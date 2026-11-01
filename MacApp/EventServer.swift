import AirCursorKit
import Foundation
import Network

/// Tiny HTTP/1.1 keep-alive server that receives CursorEvents from the Watch (ADR-0001).
final class EventServer {
    var onEvent: ((CursorEvent) -> Void)?
    var onStateChange: ((String) -> Void)?

    private let queue = DispatchQueue(label: "aircursor.server", qos: .userInteractive)
    private var listener: NWListener?
    private let pin: () -> String
    private let deviceName: String

    init(pin: @escaping () -> String, deviceName: String) {
        self.pin = pin
        self.deviceName = deviceName
    }

    func start(port: UInt16) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        if let tcp = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
        }
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        listener.service = NWListener.Service(name: deviceName, type: AirCursorProtocol.bonjourType)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.onStateChange?("Siap")
            case .failed(let error): self?.onStateChange?("Gagal: \(error.localizedDescription)")
            default: break
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            do {
                // A keep-alive connection may deliver several requests in one read.
                while let (request, consumed) = try HTTPParser.parse(buffer) {
                    buffer = Data(buffer.dropFirst(consumed))
                    connection.send(content: self.handle(request), completion: .contentProcessed { _ in })
                }
            } catch {
                connection.send(content: HTTPParser.response(status: 400, reason: "Bad Request"),
                                completion: .contentProcessed { _ in connection.cancel() })
                return
            }

            if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(on: connection, buffer: buffer)
            }
        }
    }

    private func handle(_ request: HTTPRequest) -> Data {
        guard request.header(AirCursorProtocol.pinHeader) == pin() else {
            return HTTPParser.response(status: 401, reason: "Unauthorized")
        }

        switch (request.method, request.path) {
        case ("GET", AirCursorProtocol.pingPath):
            let body = (try? JSONEncoder().encode(PingResponse(name: deviceName))) ?? Data()
            onStateChange?("Terhubung")
            return HTTPParser.response(status: 200, reason: "OK", body: body, contentType: "application/json")

        case ("POST", AirCursorProtocol.eventsPath):
            guard let event = try? JSONDecoder().decode(CursorEvent.self, from: request.body) else {
                return HTTPParser.response(status: 400, reason: "Bad Request")
            }
            onEvent?(event)
            return HTTPParser.response(status: 204, reason: "No Content")

        default:
            return HTTPParser.response(status: 404, reason: "Not Found")
        }
    }
}
