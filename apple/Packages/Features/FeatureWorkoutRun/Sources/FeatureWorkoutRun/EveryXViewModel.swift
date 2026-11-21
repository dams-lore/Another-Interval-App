import Foundation
import Observation
import Domain
import TimerEngine

/// Comment l'athlète valide sa progression dans un set.
public enum EveryXValidation: Sendable, Equatable {
    /// Un tap à la fin de chaque étape : on obtient un temps par étape.
    case perStep
    /// Un seul tap à la fin du set.
    case perSet
}

/// État visuel d'un set dans la rangée de pastilles.
public enum SetBadge: Sendable, Equatable {
    case todo, current, done, notFinished
}

/// ViewModel du parcours « Every X × N » : un set part toutes les X minutes ; dans chaque set,
/// l'athlète enchaîne les étapes et les valide au tap. Le temps vient du `TimerEngine`
/// (intervalles), le suivi des étapes et des splits est fait ici.
@MainActor @Observable
public final class EveryXViewModel {
    public let workout: Workout

    // Réglages choisis avant le départ.
    public var validation: EveryXValidation = .perStep
    public var countdown: TimeInterval = 10

    public private(set) var hasStarted = false
    public private(set) var state: RunState = .idle
    /// Sets terminés ou abandonnés (le set en cours n'y est pas encore).
    public private(set) var results: [SetResult] = []
    public private(set) var currentStepIndex = 0

    private var currentSplits: [StepSplit] = []
    private var stepStart: TimeInterval = 0
    private var completionTime: TimeInterval?
    private var trackedSet = 0
    private var finalized = false

    private var engine: TimerEngine?
    private var detector = RunEventDetector()
    private let clock: any AppClock
    private let guidance: (any GuidanceOutput)?

    public init(workout: Workout, clock: any AppClock = SystemClock(), guidance: (any GuidanceOutput)? = nil) {
        self.workout = workout
        self.clock = clock
        self.guidance = guidance
    }

    // MARK: - Données de la séance

    public var steps: [Step] { workout.steps }
    public var setCount: Int { max(1, workout.rounds ?? 1) }
    public var interval: TimeInterval {
        let value = workout.intervalSeconds ?? 60
        return value > 0 ? value : 60
    }
    public var totalDuration: TimeInterval { interval * Double(setCount) }
    public var stepLines: [String] { steps.map(StepFormat.line(for:)) }

    /// Nombre de taps nécessaires par set avec le mode choisi.
    public var tapsPerSet: Int { validation == .perStep ? max(1, steps.count) : 1 }

    // MARK: - Actions

    public func start() {
        guard !hasStarted else { return }
        var newEngine = TimerEngine(configuration: RunConfiguration(workout: workout, countdown: countdown))
        newEngine.start(at: clock.now())
        engine = newEngine
        hasStarted = true
        refresh()
    }

    /// Met à jour l'affichage et déclenche les signaux (appelé ~5 fois par seconde).
    public func refresh() {
        guard let engine else { return }
        state = engine.state(at: clock.now())
        syncSet()
        for event in detector.events(for: state) {
            guidance?.play(RunViewModel.cue(for: event))
        }
    }

    /// Valide l'étape en cours (ou le set entier en mode « 1 tap »).
    public func tap() {
        guard hasStarted, state.phase == .running, completionTime == nil, let setElapsed = state.blockElapsed else { return }
        switch validation {
        case .perSet:
            completionTime = setElapsed
            guidance?.play(.setDone)
        case .perStep:
            guard currentStepIndex < steps.count else { return }
            let step = steps[currentStepIndex]
            currentSplits.append(StepSplit(stepIndex: currentStepIndex, movement: step.movement, duration: setElapsed - stepStart))
            stepStart = setElapsed
            currentStepIndex += 1
            if currentStepIndex >= steps.count {
                completionTime = setElapsed
                guidance?.play(.setDone)
            } else {
                guidance?.play(.stepDone)
            }
        }
    }

    /// « Annuler, set pas fini » : corrige un tap fait trop tôt et reprend la dernière étape.
    public func undoSetCompletion() {
        guard completionTime != nil, state.phase != .finished else { return }
        completionTime = nil
        if validation == .perStep, let last = currentSplits.popLast() {
            currentStepIndex = last.stepIndex
            stepStart -= last.duration
        }
    }

    public func togglePause() {
        guard var engine else { return }
        if state.phase == .paused {
            engine.resume(at: clock.now())
        } else {
            engine.pause(at: clock.now())
        }
        self.engine = engine
        refresh()
    }

    public func stop() {
        guard var engine else { return }
        engine.finish(at: clock.now())
        self.engine = engine
        refresh()
    }

    // MARK: - Suivi des sets

    private func syncSet() {
        guard state.phase != .idle, state.phase != .countdown else { return }
        if state.roundIndex != trackedSet {
            // Un nouveau set démarre (automatiquement, même si le précédent n'est pas fini).
            finalizeCurrentSet()
            trackedSet = state.roundIndex
            currentSplits = []
            currentStepIndex = 0
            stepStart = 0
            completionTime = nil
        }
        if state.phase == .finished, !finalized {
            finalizeCurrentSet()
            finalized = true
        }
    }

    private func finalizeCurrentSet() {
        results.append(SetResult(setIndex: trackedSet, splits: currentSplits, completionTime: completionTime, interval: interval))
    }

    // MARK: - Valeurs affichées

    public var isFinished: Bool { state.phase == .finished }
    public var isCountdown: Bool { state.phase == .countdown }
    public var isPaused: Bool { state.phase == .paused }

    /// Set terminé, on attend le prochain : écran de repos.
    public var isResting: Bool { completionTime != nil && !isFinished }

    public var setNumber: Int { min(state.roundIndex + 1, setCount) }
    public var stepNumber: Int { min(currentStepIndex + 1, max(1, steps.count)) }

    public var currentStepTitle: String {
        guard !steps.isEmpty else { return workout.name }
        return StepFormat.line(for: steps[min(currentStepIndex, steps.count - 1)])
    }

    /// Titre du bouton principal : « Row fini » (nom de l'étape + fini), ou « Set fini » en mode 1 tap.
    public var doneButtonTitle: String {
        guard validation == .perStep, !steps.isEmpty else { return "Set fini" }
        let name = steps[min(currentStepIndex, steps.count - 1)].movement
        let shortName = name.split(separator: " ").first.map(String.init) ?? name
        return "\(shortName) fini"
    }

    /// Première étape du prochain set (écran de repos).
    public var nextStepTitle: String? {
        guard state.roundIndex + 1 < setCount, let first = steps.first else { return nil }
        return StepFormat.line(for: first)
    }

    public var countdownText: String { String(Int(state.countdownRemaining.rounded(.up))) }
    /// Gros chrono : temps restant avant le prochain set.
    public var windowRemainingText: String { RunFormat.short(state.blockRemaining ?? 0, roundingUp: true) }
    public var setElapsedText: String { RunFormat.short(state.blockElapsed ?? 0) }
    public var totalElapsedText: String { RunFormat.short(state.elapsed) }
    public var completionTimeText: String { RunFormat.short(completionTime ?? 0) }

    /// Segments d'avancement des étapes du set en cours (vrai = étape validée).
    public var segmentStates: [Bool] {
        let count = validation == .perStep ? max(1, steps.count) : 1
        return (0..<count).map { index in
            validation == .perStep ? index < currentStepIndex : completionTime != nil
        }
    }

    public var badges: [SetBadge] {
        (0..<setCount).map { index in
            if let result = results.first(where: { $0.setIndex == index }) {
                return result.isCompleted ? .done : .notFinished
            }
            if index == state.roundIndex, hasStarted, !isFinished { return completionTime != nil ? .done : .current }
            return .todo
        }
    }

    // MARK: - Récap de fin

    public var summary: EveryXSummary { EveryXSummary(results: results.sorted { $0.setIndex < $1.setIndex }, totalSets: setCount) }

    /// Texte à copier : « Copier le résultat ».
    public var shareText: String {
        var lines = ["\(workout.name) — \(summary.completedCount)/\(setCount) sets"]
        if let average = summary.averageTime { lines.append("Moyenne \(RunFormat.short(average))") }
        for result in summary.results {
            let time = result.completionTime.map { RunFormat.short($0) } ?? "non fini"
            let splits = result.splits.map { "\($0.movement.lowercased()) \(RunFormat.short($0.duration))" }.joined(separator: " · ")
            lines.append("Set \(result.setIndex + 1) : \(time)" + (splits.isEmpty ? "" : " (\(splits))"))
        }
        return lines.joined(separator: "\n")
    }

    /// Phrase d'explication du récap de départ.
    public var explanationText: String {
        "Un set part toutes les \(RunFormat.short(interval)), \(RunFormat.short(totalDuration)) au total. "
            + "Le temps gagné est ton repos. Si un set n'est pas fini à \(RunFormat.short(interval)), "
            + "le suivant part quand même et le set est noté non fini."
    }
}
