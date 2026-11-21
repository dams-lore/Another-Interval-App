import Foundation

/// Événements déduits de l'évolution de l'état (consommés par l'audio, les haptics, les montres).
public enum RunEvent: Sendable, Equatable {
    case countdownTick(Int)
    case go
    case tenSecondsLeft
    case blockEnded
    case sessionFinished
}

/// Compare chaque nouvel état au précédent et émet chaque événement **une seule fois**,
/// même si l'état est rafraîchi plusieurs fois par seconde. Pur et testable.
public struct RunEventDetector: Sendable {
    private var previous: RunState?
    private var lastTick: Int?
    private var warnedKey: Int?
    private var hasStarted = false

    public init() {}

    public mutating func events(for state: RunState) -> [RunEvent] {
        defer { previous = state }
        var events: [RunEvent] = []

        switch state.phase {
        case .idle, .paused:
            break

        case .countdown:
            let remaining = Int(state.countdownRemaining.rounded(.up))
            if (1...3).contains(remaining), remaining != lastTick {
                lastTick = remaining
                events.append(.countdownTick(remaining))
            }

        case .running:
            if !hasStarted {
                hasStarted = true
                events.append(.go)
            } else if let previous, state.blockRemaining != nil,
                      previous.roundIndex != state.roundIndex || previous.blockIndex != state.blockIndex {
                events.append(.blockEnded)
            }
            if let warning = tenSecondsWarning(for: state) {
                events.append(warning)
            }

        case .finished:
            if let previous, previous.phase != .finished, previous.phase != .idle {
                events.append(.sessionFinished)
            }
        }
        return events
    }

    private mutating func tenSecondsWarning(for state: RunState) -> RunEvent? {
        let isCyclic = state.blockRemaining != nil
        let remaining = state.blockRemaining ?? state.totalRemaining
        let length: TimeInterval = isCyclic
            ? (state.blockElapsed ?? 0) + (state.blockRemaining ?? 0)
            : state.elapsed + (state.totalRemaining ?? 0)
        guard let remaining, remaining > 0, remaining <= 10, length > 10 else { return nil }

        let key = isCyclic ? state.roundIndex * 10_000 + state.blockIndex : -1
        guard warnedKey != key else { return nil }
        warnedKey = key
        return .tenSecondsLeft
    }
}
