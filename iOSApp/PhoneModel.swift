import AirCursorKit
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PhoneModel {
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
    /// When true the cursor only moves while a thumb is on the pad; otherwise it always follows the phone.
    var holdToMove: Bool {
        didSet {
            UserDefaults.standard.set(holdToMove, forKey: "holdToMove")
            if isRunning { setMoving(!holdToMove) }
        }
    }

    private(set) var status: Status = .idle
    private(set) var isRunning = false
    private(set) var isMoving = false

    @ObservationIgnored private let streamer = MotionStreamer(axes: .handheld)
    @ObservationIgnored private let tapFeedback = UIImpactFeedbackGenerator(style: .medium)

    init() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "host") ?? ""
        pin = defaults.string(forKey: "pin") ?? ""
        holdToMove = defaults.object(forKey: "holdToMove") as? Bool ?? true
        settings = defaults.data(forKey: "settings")
            .flatMap { try? JSONDecoder().decode(MotionSettings.self, from: $0) } ?? MotionSettings()

        streamer.update(settings: settings)
        streamer.onResult = { [weak self] result in
            Task { @MainActor in self?.handle(result) }
        }
    }

    var canConnect: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty && pin.count == 4
    }

    func connect(to mac: MacBrowser.FoundMac) async {
        status = .checking
        do {
            host = try await MacBrowser.resolve(mac.endpoint)
            await connect()
        } catch {
            status = .error("Tidak bisa menjangkau \(mac.name): \(error.localizedDescription)")
        }
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
        setMoving(!holdToMove)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stop() {
        streamer.stop()
        isRunning = false
        isMoving = false
        UIApplication.shared.isIdleTimerDisabled = false
        if case .connected = status { status = .idle }
    }

    func setMoving(_ moving: Bool) {
        guard moving != isMoving else { return }
        isMoving = moving
        streamer.setMoving(moving)
    }

    func click(_ kind: ClickKind) {
        streamer.click(kind)
        tapFeedback.impactOccurred()
    }

    func scroll(_ amount: Double) {
        streamer.scroll(amount)
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
}
