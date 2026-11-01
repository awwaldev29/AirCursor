import Foundation

/// Wire protocol shared by the Watch (sender) and the Mac (receiver). See docs/PRD.md §6.
public enum AirCursorProtocol {
    public static let version = 1
    public static let defaultPort: UInt16 = 8787
    public static let pinHeader = "X-AirCursor-PIN"
    public static let eventsPath = "/v1/events"
    public static let pingPath = "/v1/ping"
    /// Bonjour service type the Mac advertises so the iPhone can find it without typing an IP.
    public static let bonjourType = "_aircursor._tcp"
}

public enum ClickKind: String, Codable, Sendable, Equatable {
    case left
    case right
}

/// One batch of input. Movement and scroll are summed since the previous batch.
public struct CursorEvent: Codable, Sendable, Equatable {
    public var dx: Double
    public var dy: Double
    public var scroll: Double
    public var clicks: [ClickKind]

    public init(dx: Double = 0, dy: Double = 0, scroll: Double = 0, clicks: [ClickKind] = []) {
        self.dx = dx
        self.dy = dy
        self.scroll = scroll
        self.clicks = clicks
    }

    public var isEmpty: Bool {
        dx == 0 && dy == 0 && scroll == 0 && clicks.isEmpty
    }
}

public struct PingResponse: Codable, Sendable, Equatable {
    public var name: String
    public var version: Int

    public init(name: String, version: Int = AirCursorProtocol.version) {
        self.name = name
        self.version = version
    }
}

/// Collects input between network sends so that at most one request is in flight (ADR-0001).
public struct PendingEvents: Sendable {
    private var event = CursorEvent()

    public init() {}

    public mutating func move(dx: Double, dy: Double) {
        event.dx += dx
        event.dy += dy
    }

    public mutating func scroll(_ amount: Double) {
        event.scroll += amount
    }

    public mutating func click(_ kind: ClickKind) {
        event.clicks.append(kind)
    }

    /// Returns everything collected so far and resets, or nil when there is nothing to send.
    public mutating func drain() -> CursorEvent? {
        guard !event.isEmpty else { return nil }
        defer { event = CursorEvent() }
        return event
    }
}
