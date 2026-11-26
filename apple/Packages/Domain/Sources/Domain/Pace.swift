import Foundation

/// Conversions d'allure et de vitesse (règles métier pures).
public enum Pace {
    /// Allure en secondes par kilomètre. `nil` si la distance ou la durée est nulle.
    public static func secondsPerKilometer(distanceMeters: Double, duration: TimeInterval) -> Double? {
        guard distanceMeters > 0, duration > 0 else { return nil }
        return duration / (distanceMeters / 1000)
    }

    /// Vitesse en km/h. `nil` si la distance ou la durée est nulle.
    public static func kilometersPerHour(distanceMeters: Double, duration: TimeInterval) -> Double? {
        guard distanceMeters > 0, duration > 0 else { return nil }
        return (distanceMeters / 1000) / (duration / 3600)
    }
}
