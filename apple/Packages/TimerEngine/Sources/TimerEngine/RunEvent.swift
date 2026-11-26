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
            } else if let previous, state.isBlockBased,
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
        let remaining: TimeInterval
        let length: TimeInterval
        let key: Int
        if state.isBlockBased {
            // Les blocs manuels (reps, distance) n'ont pas de fin chronométrée : pas d'alerte.
            guard let blockRemaining = state.blockRemaining else { return nil }
            remaining = blockRemaining
            length = (state.blockElapsed ?? 0) + blockRemaining
            key = state.roundIndex * 10_000 + state.blockIndex
        } else {
            guard let totalRemaining = state.totalRemaining else { return nil }
            remaining = totalRemaining
            length = state.elapsed + totalRemaining
            key = -1
        }
        guard remaining > 0, remaining <= 10, length > 10, warnedKey != key else { return nil }
        warnedKey = key
        return .tenSecondsLeft
    }
}
