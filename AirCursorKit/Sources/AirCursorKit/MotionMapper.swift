import Foundation

public struct MotionSettings: Codable, Sendable, Equatable {
    /// Pixels per radian of wrist rotation at low speed.
    public var sensitivity: Double
    /// Extra gain per rad/s, so fast flicks travel further than slow aiming.
    public var acceleration: Double
    /// Rotation rates below this (rad/s) are treated as noise / gyro drift.
    public var deadzone: Double
    public var invertX: Bool
    public var invertY: Bool

    public init(
        sensitivity: Double = 900,
        acceleration: Double = 0.6,
        deadzone: Double = 0.04,
        invertX: Bool = false,
        invertY: Bool = false
    ) {
        self.sensitivity = sensitivity
        self.acceleration = acceleration
        self.deadzone = deadzone
        self.invertX = invertX
        self.invertY = invertY
    }
}

/// Turns gyroscope rotation rates into relative cursor deltas (ADR-0002).
///
/// Assumes the Watch is on the left wrist, hand pointing at the screen, palm down:
/// yaw (rotation about the Watch's z axis) moves the cursor horizontally,
/// pitch (rotation about its y axis) moves it vertically.
public struct MotionMapper: Sendable {
    public var settings: MotionSettings

    public init(settings: MotionSettings = MotionSettings()) {
        self.settings = settings
    }

    /// - Parameters:
    ///   - rotationRateY: pitch rate in rad/s.
    ///   - rotationRateZ: yaw rate in rad/s.
    ///   - dt: seconds since the previous sample.
    /// - Returns: cursor delta in screen points (y grows downwards).
    public func delta(rotationRateY: Double, rotationRateZ: Double, dt: Double) -> (dx: Double, dy: Double) {
        let x = axis(-rotationRateZ, dt: dt) * (settings.invertX ? -1 : 1)
        let y = axis(rotationRateY, dt: dt) * (settings.invertY ? -1 : 1)
        return (x, y)
    }

    private func axis(_ rate: Double, dt: Double) -> Double {
        let magnitude = abs(rate)
        guard magnitude > settings.deadzone, dt > 0 else { return 0 }
        // Subtract the deadzone so movement ramps up from zero instead of jumping.
        let effective = (magnitude - settings.deadzone) * (rate < 0 ? -1 : 1)
        let gain = settings.sensitivity * (1 + settings.acceleration * magnitude)
        return effective * gain * dt
    }
}
