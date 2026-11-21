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
    private var detector = RunEventDetector()
    private let clock: any AppClock
    private let guidance: (any GuidanceOutput)?

    public init(
        workout: Workout,
        clock: any AppClock = SystemClock(),
        countdown: TimeInterval = 10,
        guidance: (any GuidanceOutput)? = nil
    ) {
        self.workout = workout
        self.clock = clock
        self.guidance = guidance
        self.engine = TimerEngine(configuration: RunConfiguration(workout: workout, countdown: countdown))
    }

    // MARK: - Actions

    /// Met à jour l'état affiché et déclenche les bips / vibrations (une seule fois par événement).
    public func refresh() {
        state = engine.state(at: clock.now())
        for event in detector.events(for: state) {
            guidance?.play(Self.cue(for: event))
        }
    }

    static func cue(for event: RunEvent) -> GuidanceCue {
        switch event {
        case .countdownTick(let n): .countdownTick(n)
        case .go: .go
        case .tenSecondsLeft: .tenSecondsWarning
        case .blockEnded: .blockEnd
        case .sessionFinished: .sessionEnd
        }
    }

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
    private var isCyclic: Bool { configuration.isCyclic }

    /// Chrono central : compte à rebours, temps du bloc (EMOM / fractionné) ou temps écoulé.
    public var mainTimerText: String {
        switch state.phase {
        case .idle: return "00:00"
        case .countdown: return RunFormat.remaining(state.countdownRemaining)
        default:
            if let remaining = state.blockRemaining { return RunFormat.remaining(remaining) }
            // Bloc manuel (reps, distance) : on compte le temps passé sur le bloc.
            if isCyclic, let blockElapsed = state.blockElapsed { return RunFormat.elapsed(blockElapsed) }
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
        if configuration.format == .emom {
            return "INTERVALLE \(state.roundIndex + 1) / \(configuration.rounds)"
        }
        return "BLOCK \(state.blockIndex + 1) / \(configuration.cycle.count)"
    }

    /// Étape en cours pour un fractionné (un bloc de la séance = une étape).
    private var currentStep: Step? {
        guard configuration.format == .intervals, !workout.steps.isEmpty else { return nil }
        return workout.steps[state.blockIndex % workout.steps.count]
    }

    public var blockTitle: String {
        if configuration.format == .emom {
            let seconds = configuration.cycle.first.flatMap { $0 } ?? 60
            let total = Int(seconds.rounded())
            return String(format: "Every %d:%02d", total / 60, total % 60)
        }
        return currentStep?.movement ?? workout.name
    }

    /// Lignes à afficher sous le titre : tout ce qu'il y a à faire pendant l'intervalle (EMOM),
    /// ou le détail du bloc courant (fractionné).
    public var blockLines: [String] {
        if configuration.format == .emom { return workout.steps.map { StepFormat.line(for: $0) } }
        if let step = currentStep, step.type != .time { return [StepFormat.line(for: step)] }
        return []
    }

    /// Vrai si le bloc courant n'a pas de durée : l'athlète le termine lui-même.
    public var currentBlockIsManual: Bool {
        isCyclic && configuration.cycle[state.blockIndex % configuration.cycle.count] == nil
    }

    public var advanceLabel: String {
        if !isCyclic { return "＋  Tour" }
        return currentBlockIsManual ? "✓  Bloc terminé" : "⏭  Skip"
    }

    /// Bouton principal : bloc suivant (EMOM, fractionné) ou +1 tour (For Time, AMRAP).
    public func advance() {
        if isCyclic { skip() } else { completeRound() }
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
