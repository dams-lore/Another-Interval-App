import Foundation

/// Machine à états d'exécution d'une séance (docs/architecture.md § 5).
///
/// Le temps est **toujours calculé à partir d'horodatages** (début + pauses cumulées),
/// jamais en additionnant des ticks : l'état reste juste après un verrouillage d'écran
/// ou une mise en arrière-plan. L'appelant fournit l'instant (`Date`), ce qui rend le
/// moteur déterministe et testable sans attendre.
public struct TimerEngine: Sendable {
    public let configuration: RunConfiguration

    private var startedAt: Date?
    private var pausedAt: Date?
    private var pausedTotal: TimeInterval = 0
    private var skipOffset: TimeInterval = 0
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

    /// Passe au bloc suivant (EMOM et fractionné). Sans effet pour For Time / AMRAP.
    public mutating func skip(at now: Date) {
        let current = state(at: now)
        guard current.phase == .running, configuration.isCyclic,
              let remaining = current.blockRemaining else { return }
        skipOffset += remaining + 1e-9
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
            return state
        }

        let elapsed = raw - configuration.countdown + skipOffset
        let total = configuration.totalDuration

        if let manualFinishElapsed {
            return build(phase: .finished, elapsed: manualFinishElapsed, total: total)
        }
        if let total, elapsed >= total {
            return build(phase: .finished, elapsed: total, total: total)
        }
        return build(phase: pausedAt != nil ? .paused : .running, elapsed: elapsed, total: total)
    }

    // MARK: - Interne

    private func rawElapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        let reference = pausedAt ?? now
        return max(0, reference.timeIntervalSince(startedAt) - pausedTotal)
    }

    private func build(phase: RunPhase, elapsed: TimeInterval, total: TimeInterval?) -> RunState {
        var state = RunState.idle
        state.phase = phase
        state.elapsed = max(0, elapsed)
        state.totalRemaining = total.map { max(0, $0 - state.elapsed) }

        guard configuration.isCyclic else {
            state.roundsCompleted = completedRounds
            state.roundIndex = completedRounds
            return state
        }

        let cycle = configuration.cycle
        let cycleLength = configuration.cycleLength
        let finishedAllRounds = phase == .finished && (total.map { state.elapsed >= $0 } ?? false)

        var cycleIndex = Int(state.elapsed / cycleLength)
        if cycleIndex >= configuration.rounds { cycleIndex = configuration.rounds - 1 }
        var within = state.elapsed - Double(cycleIndex) * cycleLength

        var block = 0
        while block < cycle.count - 1, within >= cycle[block] {
            within -= cycle[block]
            block += 1
        }

        state.roundIndex = cycleIndex
        state.blockIndex = block
        state.blockElapsed = max(0, within)
        state.blockRemaining = phase == .finished ? 0 : max(0, cycle[block] - within)
        state.roundsCompleted = finishedAllRounds ? configuration.rounds : cycleIndex
        return state
    }
}
