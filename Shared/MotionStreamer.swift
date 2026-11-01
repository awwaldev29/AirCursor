import AirCursorKit
import CoreMotion
import Foundation

/// Reads the gyroscope, maps it to cursor deltas and streams them to the Mac.
/// At most one request is in flight; input that arrives meanwhile rides along in the next one (ADR-0001).
/// Shared by the Watch and iPhone apps.
final class MotionStreamer: @unchecked Sendable {
    /// Which gyroscope axes mean "turn left/right" and "tilt up/down" for how the device is held.
    struct Axes: Sendable {
        /// Yaw rate in rad/s, positive when turning left.
        var yaw: @Sendable (CMRotationRate) -> Double
        /// Pitch rate in rad/s, positive when the pointing end tilts down.
        var pitch: @Sendable (CMRotationRate) -> Double

        /// Watch on the left wrist, palm down, hand pointing at the screen (ADR-0002).
        static let wrist = Axes(yaw: { $0.z }, pitch: { $0.y })
        /// iPhone held flat like a remote, top edge pointing at the screen.
        static let handheld = Axes(yaw: { $0.z }, pitch: { -$0.x })
    }

    enum SendResult: Sendable {
        case ok
        case unauthorized
        case failed(String)
    }

    var onResult: (@Sendable (SendResult) -> Void)?

    private let motion = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "aircursor.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.httpMaximumConnectionsPerHost = 1
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private let lock = NSLock()
    private var pending = PendingEvents()
    private var mapper = MotionMapper()
    private let axes: Axes
    private var isMoving = false
    private var lastTimestamp: TimeInterval?
    private var sendTask: Task<Void, Never>?

    init(axes: Axes) {
        self.axes = axes
    }

    var isMotionAvailable: Bool { motion.isDeviceMotionAvailable }

    func update(settings: MotionSettings) {
        lock.withLock { mapper.settings = settings }
    }

    /// Clutch: while paused, clicks and scroll still work but wrist movement is ignored.
    func setMoving(_ moving: Bool) {
        lock.withLock {
            isMoving = moving
            lastTimestamp = nil
        }
    }

    func click(_ kind: ClickKind) {
        lock.withLock { pending.click(kind) }
    }

    func scroll(_ amount: Double) {
        lock.withLock { pending.scroll(amount) }
    }

    func start(host: String, pin: String) {
        stop()
        guard let url = Self.url(host: host, path: AirCursorProtocol.eventsPath) else {
            onResult?(.failed("Alamat IP tidak valid"))
            return
        }

        motion.deviceMotionUpdateInterval = 1.0 / 60
        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.lock.withLock {
                defer { self.lastTimestamp = data.timestamp }
                guard self.isMoving, let last = self.lastTimestamp else { return }
                let delta = self.mapper.delta(
                    rotationRateY: self.axes.pitch(data.rotationRate),
                    rotationRateZ: self.axes.yaw(data.rotationRate),
                    dt: data.timestamp - last
                )
                self.pending.move(dx: delta.dx, dy: delta.dy)
            }
        }

        sendTask = Task.detached(priority: .userInitiated) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let event = self.lock.withLock({ self.pending.drain() }) {
                    let result = await self.send(event, to: url, pin: pin)
                    self.onResult?(result)
                    if case .failed = result {
                        // Back off a little so a missing Mac does not spin the CPU and radio.
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                } else {
                    try? await Task.sleep(for: .milliseconds(8))
                }
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        sendTask?.cancel()
        sendTask = nil
        lock.withLock {
            pending = PendingEvents()
            lastTimestamp = nil
        }
    }

    /// Checks that the Mac is reachable and the PIN is right. Returns the Mac's name.
    func ping(host: String, pin: String) async throws -> String {
        guard let url = Self.url(host: host, path: AirCursorProtocol.pingPath) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue(pin, forHTTPHeaderField: AirCursorProtocol.pinHeader)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw PingError.wrongPIN }
        guard status == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(PingResponse.self, from: data).name
    }

    enum PingError: LocalizedError {
        case wrongPIN
        var errorDescription: String? { "PIN salah" }
    }

    private func send(_ event: CursorEvent, to url: URL, pin: String) async -> SendResult {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(pin, forHTTPHeaderField: AirCursorProtocol.pinHeader)
        request.httpBody = try? JSONEncoder().encode(event)
        do {
            let (_, response) = try await session.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode {
            case 204: return .ok
            case 401: return .unauthorized
            case let code: return .failed("HTTP \(code ?? 0)")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func url(host: String, path: String) -> URL? {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let hostPart = trimmed.contains(":") ? trimmed : "\(trimmed):\(AirCursorProtocol.defaultPort)"
        return URL(string: "http://\(hostPart)\(path)")
    }
}
