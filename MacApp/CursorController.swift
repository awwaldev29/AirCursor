import AirCursorKit
import CoreGraphics

/// Applies incoming events to the system cursor with CGEvent.
/// Requires the Accessibility permission; without it macOS silently drops the events.
final class CursorController {
    private let source = CGEventSource(stateID: .hidSystemState)
    // Sub-pixel remainders, so slow movements still add up instead of being rounded away.
    private var remainder = CGPoint.zero
    private var scrollRemainder = 0.0

    func apply(_ event: CursorEvent) {
        var location = CGEvent(source: nil)?.location ?? .zero

        if event.dx != 0 || event.dy != 0 {
            let x = event.dx + remainder.x
            let y = event.dy + remainder.y
            remainder = CGPoint(x: x - x.rounded(.towardZero), y: y - y.rounded(.towardZero))
            let target = CGPoint(x: location.x + x.rounded(.towardZero), y: location.y + y.rounded(.towardZero))
            location = Self.clampToDisplays(target, fallback: location)
            post(.mouseMoved, at: location, button: .left)
        }

        if event.scroll != 0 {
            let total = event.scroll + scrollRemainder
            let lines = total.rounded(.towardZero)
            scrollRemainder = total - lines
            if lines != 0 {
                CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1,
                        wheel1: Int32(lines), wheel2: 0, wheel3: 0)?
                    .post(tap: .cghidEventTap)
            }
        }

        for click in event.clicks {
            switch click {
            case .left:
                post(.leftMouseDown, at: location, button: .left)
                post(.leftMouseUp, at: location, button: .left)
            case .right:
                post(.rightMouseDown, at: location, button: .right)
                post(.rightMouseUp, at: location, button: .right)
            }
        }
    }

    private func post(_ type: CGEventType, at point: CGPoint, button: CGMouseButton) {
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button)?
            .post(tap: .cghidEventTap)
    }

    /// Keeps the cursor on a real display, allowing it to cross into neighbouring screens.
    private static func clampToDisplays(_ point: CGPoint, fallback: CGPoint) -> CGPoint {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        let bounds = displays.map { CGDisplayBounds($0) }

        if bounds.contains(where: { $0.contains(point) }) { return point }
        let current = bounds.first(where: { $0.contains(fallback) }) ?? bounds.first ?? .zero
        return CGPoint(
            x: min(max(point.x, current.minX), current.maxX - 1),
            y: min(max(point.y, current.minY), current.maxY - 1)
        )
    }
}
