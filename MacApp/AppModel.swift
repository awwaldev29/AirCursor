import AirCursorKit
import AppKit
import ApplicationServices
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var pin: String
    private(set) var addresses: [String] = []
    private(set) var isTrusted = AXIsProcessTrusted()
    private(set) var serverState = "Memulai…"
    private(set) var lastEventAt: Date?
    private(set) var eventCount = 0
    /// Ticks every second so time-based state like `isReceiving` refreshes in the UI.
    private(set) var now = Date()

    let port = AirCursorProtocol.defaultPort

    @ObservationIgnored private var server: EventServer?
    @ObservationIgnored private let cursor = CursorController()
    @ObservationIgnored private var pinBox: PinBox
    @ObservationIgnored private var trustTimer: Timer?

    var isReceiving: Bool {
        guard let lastEventAt else { return false }
        return now.timeIntervalSince(lastEventAt) < 2
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "pin")
        let pin = saved ?? Self.makePIN()
        self.pin = pin
        self.pinBox = PinBox(pin)
        UserDefaults.standard.set(pin, forKey: "pin")
        addresses = NetworkInfo.localIPv4Addresses()
        startServer()
        startTrustPolling()
    }

    func regeneratePIN() {
        pin = Self.makePIN()
        pinBox.value = pin
        UserDefaults.standard.set(pin, forKey: "pin")
    }

    func refreshAddresses() {
        addresses = NetworkInfo.localIPv4Addresses()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        if !isTrusted,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startServer() {
        let pinBox = self.pinBox
        let server = EventServer(pin: { pinBox.value }, deviceName: Host.current().localizedName ?? "Mac")
        let cursor = self.cursor
        server.onEvent = { [weak self] event in
            // Post on the server queue for the lowest latency; only UI bookkeeping hops to main.
            cursor.apply(event)
            Task { @MainActor in
                self?.lastEventAt = Date()
                self?.now = Date()
                self?.eventCount += 1
            }
        }
        server.onStateChange = { [weak self] state in
            Task { @MainActor in self?.serverState = state }
        }
        do {
            try server.start(port: port)
            self.server = server
        } catch {
            serverState = "Gagal: \(error.localizedDescription)"
        }
    }

    private func startTrustPolling() {
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isTrusted = AXIsProcessTrusted()
                self.now = Date()
            }
        }
    }

    private static func makePIN() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }
}

/// Thread-safe holder so the server queue can read the PIN while the UI changes it.
private final class PinBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: String

    init(_ value: String) { _value = value }

    var value: String {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
