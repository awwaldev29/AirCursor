import AirCursorKit
import Foundation
import Observation
import WatchKit

@MainActor
@Observable
final class WatchModel: NSObject {
    enum Status: Equatable {
        case idle
        case checking
        case connected(String)
        case error(String)
    }

    var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }
    var pin: String {
        didSet { UserDefaults.standard.set(pin, forKey: "pin") }
    }
    var settings: MotionSettings {
        didSet {
            streamer.update(settings: settings)
            if let data = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(data, forKey: "settings")
            }
        }
    }

    private(set) var status: Status = .idle
    private(set) var isRunning = false
    private(set) var isMoving = false

    @ObservationIgnored private let streamer = MotionStreamer(axes: .wrist)
    @ObservationIgnored private var runtimeSession: WKExtendedRuntimeSession?

    override init() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "host") ?? ""
        pin = defaults.string(forKey: "pin") ?? ""
        settings = defaults.data(forKey: "settings")
            .flatMap { try? JSONDecoder().decode(MotionSettings.self, from: $0) } ?? MotionSettings()
        super.init()

        streamer.update(settings: settings)
        streamer.onResult = { [weak self] result in
            Task { @MainActor in self?.handle(result) }
        }
    }

    var canConnect: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty && pin.count == 4
    }

    func connect() async {
        status = .checking
        do {
            let name = try await streamer.ping(host: host, pin: pin)
            status = .connected(name)
            start()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func start() {
        streamer.start(host: host, pin: pin)
        isRunning = true
        setMoving(true)
        startRuntimeSession()
    }

    func stop() {
        streamer.stop()
        isRunning = false
        isMoving = false
        runtimeSession?.invalidate()
        runtimeSession = nil
        if case .connected = status { status = .idle }
    }

    func toggleMoving() {
        setMoving(!isMoving)
    }

    func click(_ kind: ClickKind) {
        streamer.click(kind)
        WKInterfaceDevice.current().play(kind == .left ? .click : .directionDown)
    }

    func scroll(_ amount: Double) {
        streamer.scroll(amount)
    }

    private func setMoving(_ moving: Bool) {
        isMoving = moving
        streamer.setMoving(moving)
    }

    private func handle(_ result: MotionStreamer.SendResult) {
        switch result {
        case .ok:
            if case .error = status { status = .connected(host) }
        case .unauthorized:
            stop()
            status = .error("PIN salah atau sudah diganti di Mac")
        case .failed(let message):
            status = .error(message)
        }
    }

    /// Keeps motion and networking alive when the wrist turns and the screen dims (PRD F11).
    private func startRuntimeSession() {
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        runtimeSession = session
    }
}

extension WatchModel: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSession(
        _ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {}

    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {}
}
