/// Phases de la machine à états d'exécution (docs/architecture.md § 5).
/// idle → countdown → running ⇄ paused → finished
public enum RunPhase: Sendable, Equatable {
    case idle
    case countdown
    case running
    case paused
    case finished

    public var isActive: Bool {
        switch self {
        case .countdown, .running, .paused: true
        case .idle, .finished: false
        }
    }
}
