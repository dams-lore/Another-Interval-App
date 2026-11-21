import Foundation
import Observation
import Domain
import TimerEngine

public enum RunDisplayMode: String, Sendable, CaseIterable {
    case compact
    case gym
}

/// ViewModel de l'écran de séance : ne parle qu'au Domain et au TimerEngine.
@MainActor @Observable
public final class RunViewModel {
    public let workout: Workout
    public var displayMode: RunDisplayMode = .compact
    public private(set) var state: RunState = .idle

    private var engine: TimerEngine
    private let clock: any AppClock

    public init(workout: Workout, clock: any AppClock = SystemClock(), countdown: TimeInterval = 10) {
        self.workout = workout
        self.clock = clock
        self.engine = TimerEngine(configuration: RunConfiguration(workout: workout, countdown: countdown))
    }

    // MARK: - Actions

    public func refresh() { state = engine.state(at: clock.now()) }

    public func start() {
        engine.start(at: clock.now())
        refresh()
    }

    public func togglePause() {
        if state.phase == .paused {
            engine.resume(at: clock.now())
        } else {
            engine.pause(at: clock.now())
        }
        refresh()
    }

    public func skip() {
        engine.skip(at: clock.now())
        refresh()
    }

    public func completeRound() {
        engine.completeRound(at: clock.now())
        refresh()
    }

    public func stop() {
        engine.finish(at: clock.now())
        refresh()
    }

    // MARK: - Valeurs affichées

    private var configuration: RunConfiguration { engine.configuration }
    private var isCyclic: Bool { state.blockRemaining != nil }

    private var timedSteps: [Step] {
        workout.steps.filter { $0.type == .time && $0.value > 0 }
    }

    /// Chrono central : compte à rebours, temps du bloc (EMOM / fractionné) ou temps écoulé.
    public var mainTimerText: String {
        switch state.phase {
        case .idle: return "00:00"
        case .countdown: return RunFormat.remaining(state.countdownRemaining)
        default:
            if let remaining = state.blockRemaining { return RunFormat.remaining(remaining) }
            return RunFormat.elapsed(state.elapsed)
        }
    }

    /// Chrono du haut : temps total écoulé.
    public var totalTimerText: String { RunFormat.elapsed(state.elapsed) }

    public var roundText: String {
        guard isCyclic else { return "R\(state.roundsCompleted + 1)" }
        return "R\(state.roundIndex + 1)/\(configuration.rounds)"
    }

    public var blockCounterText: String {
        guard isCyclic else { return "ROUND \(state.roundsCompleted + 1)" }
        return "BLOCK \(state.blockIndex + 1) / \(configuration.cycle.count)"
    }

    public var blockTitle: String {
        guard configuration.format == .intervals, !timedSteps.isEmpty else { return workout.name }
        return timedSteps[state.blockIndex % timedSteps.count].movement
    }

    /// Avancement du bloc courant, de 0 à 1 (`nil` si le format n'a pas de blocs).
    public var blockProgress: Double? {
        guard let elapsed = state.blockElapsed, let remaining = state.blockRemaining else { return nil }
        let length = elapsed + remaining
        guard length > 0 else { return nil }
        return min(1, max(0, elapsed / length))
    }

    /// Blocs terminés / total (« 1 / 16 »). `nil` hors EMOM et fractionné.
    public var overallProgress: (done: Int, total: Int)? {
        guard isCyclic else { return nil }
        let perRound = configuration.cycle.count
        return (state.roundIndex * perRound + state.blockIndex, perRound * configuration.rounds)
    }

    public var isFinished: Bool { state.phase == .finished }
}
