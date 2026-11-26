import Foundation

/// Horloge injectable (évite le conflit de nom avec `Swift.Clock`).
/// Les tests utilisent `TestClock` (TestSupport) pour avancer le temps instantanément.
public protocol AppClock: Sendable {
    func now() -> Date
}

public struct SystemClock: AppClock {
    public init() {}
    public func now() -> Date { Date() }
}
