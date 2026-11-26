import Foundation

/// Machine à états d'exécution d'une séance (docs/architecture.md § 5).
///
/// Le temps est **toujours calculé à partir d'horodatages** (début + pauses cumulées),
/// jamais en additionnant des ticks : l'état reste juste après un verrouillage d'écran
/// ou une mise en arrière-plan. L'appelant fournit l'instant (`Date`), ce qui rend le
/// moteur déterministe et testable sans attendre.
///
/// Blocs (EMOM, fractionné) : un bloc chronométré se termine seul ; un bloc manuel (reps, distance)
/// ne se termine que par `skip`. Chaque fin anticipée est mémorisée avec son temps écoulé.
public struct TimerEngine: Sendable {
    public let configuration: RunConfiguration

    private var startedAt: Date?
    private var pausedAt: Date?
    private var pausedTotal: TimeInterval = 0
    private var earlyEnds: [Int: TimeInterval] = [:]
    private var manualFinishElapsed: TimeInterval?
    private var completedRounds = 0

    public init(configuration: RunConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Actions

    public mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    public mutating func pause(at now: Date) {
        let phase = state(at: now).phase
        guard phase == .countdown || phase == .running else { return }
        pausedAt = now
    }

    public mutating func resume(at now: Date) {
        guard let pausedAt else { return }
        pausedTotal += max(0, now.timeIntervalSince(pausedAt))
        self.pausedAt = nil
    }

    /// Termine le bloc en cours et passe au suivant (EMOM et fractionné). Sans effet pour For Time / AMRAP.
    public mutating func skip(at now: Date) {
        let current = state(at: now)
        guard current.phase == .running, configuration.isCyclic else { return }
        let ordinal = current.roundIndex * configuration.cycle.count + current.blockIndex
        earlyEnds[ordinal] = current.elapsed
    }

    /// Compte un tour terminé (For Time / AMRAP). Sans effet pour EMOM et fractionné.
    public mutating func completeRound(at now: Date) {
        guard state(at: now).phase == .running,
              configuration.format == .forTime || configuration.format == .amrap else { return }
        completedRounds += 1
    }

    /// Termine la séance (For Time : fin du chrono par l'athlète).
    public mutating func finish(at now: Date) {
        let current = state(at: now)
        guard current.phase == .running || current.phase == .paused else { return }
        manualFinishElapsed = current.elapsed
    }

    // MARK: - État

    public func state(at now: Date) -> RunState {
        guard startedAt != nil else { return .idle }

        let raw = rawElapsed(at: now)

        if raw < configuration.countdown, manualFinishElapsed == nil {
            var state = RunState.idle
            state.phase = pausedAt != nil ? .paused : .countdown
            state.countdownRemaining = configuration.countdown - raw
            state.totalRemaining = configuration.totalDuration
            state.isBlockBased = configuration.isCyclic
            return state
        }

        let elapsed = raw - configuration.countdown
        let running: RunPhase = pausedAt != nil ? .paused : .running

        if let manualFinishElapsed {
            return build(phase: .finished, elapsed: manualFinishElapsed)
        }

        if configuration.isCyclic {
            if case .finished(let end) = locate(elapsed: elapsed) {
                return build(phase: .finished, elapsed: end)
            }
            return build(phase: running, elapsed: elapsed)
        }

        if let total = configuration.totalDuration, elapsed >= total {
            return build(phase: .finished, elapsed: total)
        }
        return build(phase: running, elapsed: elapsed)
    }

    // MARK: - Interne

    private enum Location {
        case current(ordinal: Int, start: TimeInterval, end: TimeInterval?)
        case finished(at: TimeInterval)
    }

    private func rawElapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        let reference = pausedAt ?? now
        return max(0, reference.timeIntervalSince(startedAt) - pausedTotal)
    }

    /// Retrouve le bloc en cours en parcourant la séance : un bloc se termine à sa durée,
    /// ou plus tôt si l'athlète l'a passé (`earlyEnds`). Un bloc manuel n'a pas de fin naturelle.
    private func locate(elapsed: TimeInterval) -> Location {
        let cycle = configuration.cycle
        let total = cycle.count * configuration.rounds
        var start: TimeInterval = 0
        var ordinal = 0
        while ordinal < total {
            let natural = cycle[ordinal % cycle.count].map { start + $0 }
            let end = earlyEnds[ordinal] ?? natural
            if let end, elapsed >= end {
                start = end
                ordinal += 1
                continue
            }
            return .current(ordinal: ordinal, start: start, end: end)
        }
        return .finished(at: start)
    }

    private func build(phase: RunPhase, elapsed: TimeInterval) -> RunState {
        var state = RunState.idle
        state.phase = phase
        state.elapsed = max(0, elapsed)
        state.totalRemaining = configuration.totalDuration.map { max(0, $0 - state.elapsed) }

        guard configuration.isCyclic else {
            state.roundsCompleted = completedRounds
            state.roundIndex = completedRounds
            return state
        }

        state.isBlockBased = true
        let count = configuration.cycle.count
        switch locate(elapsed: state.elapsed) {
        case .finished:
            state.roundIndex = configuration.rounds - 1
            state.blockIndex = count - 1
            state.roundsCompleted = configuration.rounds
            state.blockRemaining = configuration.cycle[count - 1] == nil ? nil : 0
        case .current(let ordinal, let start, let end):
            state.roundIndex = ordinal / count
            state.blockIndex = ordinal % count
            state.blockElapsed = max(0, state.elapsed - start)
            state.blockRemaining = end.map { phase == .finished ? 0 : max(0, $0 - state.elapsed) }
            state.roundsCompleted = state.roundIndex
        }
        return state
    }
}
