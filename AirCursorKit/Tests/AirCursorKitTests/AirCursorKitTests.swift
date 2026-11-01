import Foundation
import Testing
@testable import AirCursorKit

@Suite struct MotionMapperTests {
    let mapper = MotionMapper(settings: MotionSettings(sensitivity: 1000, acceleration: 0, deadzone: 0.05))

    @Test func stillHandProducesNoMovement() {
        let d = mapper.delta(rotationRateY: 0.03, rotationRateZ: -0.04, dt: 1.0 / 60)
        #expect(d.dx == 0)
        #expect(d.dy == 0)
    }

    @Test func yawLeftMovesCursorLeft() {
        // Positive z rotation = hand turning left (counter-clockwise seen from above).
        let d = mapper.delta(rotationRateY: 0, rotationRateZ: 1.05, dt: 0.1)
        #expect(abs(d.dx - -100) < 0.0001)
        #expect(d.dy == 0)
    }

    @Test func pitchDownMovesCursorDown() {
        let d = mapper.delta(rotationRateY: 1.05, rotationRateZ: 0, dt: 0.1)
        #expect(abs(d.dy - 100) < 0.0001)
    }

    @Test func invertFlipsAxes() {
        var settings = mapper.settings
        settings.invertX = true
        settings.invertY = true
        let d = MotionMapper(settings: settings).delta(rotationRateY: 1.05, rotationRateZ: 1.05, dt: 0.1)
        #expect(d.dx > 0)
        #expect(d.dy < 0)
    }

    @Test func accelerationMakesFastMovesTravelFurther() {
        let accelerated = MotionMapper(settings: MotionSettings(sensitivity: 1000, acceleration: 1, deadzone: 0))
        let slow = accelerated.delta(rotationRateY: 0.5, rotationRateZ: 0, dt: 1).dy
        let fast = accelerated.delta(rotationRateY: 2, rotationRateZ: 0, dt: 1).dy
        #expect(fast > slow * 4)
    }
}

@Suite struct PendingEventsTests {
    @Test func drainSumsAndResets() {
        var pending = PendingEvents()
        pending.move(dx: 1, dy: 2)
        pending.move(dx: 3, dy: -1)
        pending.click(.left)
        #expect(pending.drain() == CursorEvent(dx: 4, dy: 1, clicks: [.left]))
        #expect(pending.drain() == nil)
    }
}

@Suite struct HTTPParserTests {
    @Test func parsesPostWithBody() throws {
        let raw = "POST /v1/events HTTP/1.1\r\nHost: mac\r\nX-AirCursor-PIN: 1234\r\nContent-Length: 4\r\n\r\nabcdGET"
        let result = try #require(try HTTPParser.parse(Data(raw.utf8)))
        #expect(result.request.method == "POST")
        #expect(result.request.path == "/v1/events")
        #expect(result.request.header("x-aircursor-pin") == "1234")
        #expect(result.request.body == Data("abcd".utf8))
        #expect(result.consumed == raw.utf8.count - 3)
    }

    @Test func waitsForCompleteBody() throws {
        let raw = "POST / HTTP/1.1\r\nContent-Length: 10\r\n\r\nabc"
        #expect(try HTTPParser.parse(Data(raw.utf8)) == nil)
    }

    @Test func waitsForCompleteHeaders() throws {
        #expect(try HTTPParser.parse(Data("GET / HTTP/1.1\r\nHost".utf8)) == nil)
    }

    @Test func parsesFromSlicedBuffer() throws {
        // The server keeps a rolling buffer, so slices with a non-zero startIndex must work.
        let full = Data("xxGET /v1/ping HTTP/1.1\r\n\r\n".utf8)
        let slice = full[2...]
        let result = try #require(try HTTPParser.parse(slice))
        #expect(result.request.path == "/v1/ping")
        #expect(result.consumed == slice.count)
    }

    @Test func rejectsGarbage() {
        #expect(throws: HTTPParseError.malformed) {
            try HTTPParser.parse(Data("hello\r\n\r\n".utf8))
        }
    }

    @Test func eventRoundTripsAsJSON() throws {
        let event = CursorEvent(dx: 1.5, dy: -2, scroll: 3, clicks: [.right])
        let decoded = try JSONDecoder().decode(CursorEvent.self, from: JSONEncoder().encode(event))
        #expect(decoded == event)
    }
}
