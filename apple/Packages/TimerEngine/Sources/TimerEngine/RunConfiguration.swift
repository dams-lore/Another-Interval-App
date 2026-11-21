import Foundation
import Domain

/// Paramètres d'exécution d'une séance, indépendants de l'UI.
/// - `cycle` : un élément par bloc d'un tour. `nil` = bloc **manuel** (reps, distance : l'athlète le termine
///   avec « Bloc terminé »), sinon durée en secondes. EMOM : un seul bloc de `interval`.
public struct RunConfiguration: Sendable, Equatable {
    public var format: WorkoutFormat
    public var countdown: TimeInterval
    public var cycle: [TimeInterval?]
    public var rounds: Int
    public var capTime: TimeInterval?

    public init(
        format: WorkoutFormat,
        countdown: TimeInterval = 10,
        cycle: [TimeInterval?] = [],
        rounds: Int = 1,
        capTime: TimeInterval? = nil
    ) {
        self.format = format
        self.countdown = max(0, countdown)
        self.cycle = cycle
        self.rounds = max(1, rounds)
        self.capTime = capTime
    }

    public static func forTime(cap: TimeInterval? = nil, countdown: TimeInterval = 10) -> RunConfiguration {
        RunConfiguration(format: .forTime, countdown: countdown, capTime: cap)
    }

    public static func amrap(duration: TimeInterval, countdown: TimeInterval = 10) -> RunConfiguration {
        RunConfiguration(format: .amrap, countdown: countdown, capTime: duration)
    }

    public static func emom(rounds: Int, interval: TimeInterval = 60, countdown: TimeInterval = 10) -> RunConfiguration {
        RunConfiguration(format: .emom, countdown: countdown, cycle: [interval], rounds: rounds)
    }

    public static func intervals(cycle: [TimeInterval?], rounds: Int, countdown: TimeInterval = 10) -> RunConfiguration {
        RunConfiguration(format: .intervals, countdown: countdown, cycle: cycle, rounds: rounds)
    }

    /// Construit la configuration d'une séance (les blocs `.time` définissent le cycle des fractionnés).
    public init(workout: Workout, countdown: TimeInterval = 10) {
        switch workout.format {
        case .forTime:
            self.init(format: .forTime, countdown: countdown, capTime: workout.capTime)
        case .amrap:
            self.init(format: .amrap, countdown: countdown, capTime: workout.capTime)
        case .emom:
            let interval = (workout.intervalSeconds ?? 60) > 0 ? (workout.intervalSeconds ?? 60) : 60
            self.init(format: .emom, countdown: countdown, cycle: [interval], rounds: workout.rounds ?? 1)
        case .intervals:
            // Chaque bloc de la séance devient un bloc du cycle : chronométré s'il a une durée, manuel sinon.
            let cycle: [TimeInterval?] = workout.steps.map { $0.type == .time && $0.value > 0 ? $0.value : nil }
            self.init(format: .intervals, countdown: countdown, cycle: cycle, rounds: workout.rounds ?? 1)
        }
    }

    /// Somme des blocs chronométrés d'un tour.
    var cycleLength: TimeInterval { cycle.compactMap { $0 }.reduce(0, +) }

    var hasManualBlock: Bool { cycle.contains { $0 == nil } }

    /// Vrai pour les formats découpés en blocs (EMOM, fractionné).
    public var isCyclic: Bool {
        (format == .emom || format == .intervals) && !cycle.isEmpty
    }

    /// Durée totale de la partie chronométrée (hors compte à rebours). `nil` = pas de limite
    /// (For Time sans cap, ou séance avec au moins un bloc manuel).
    public var totalDuration: TimeInterval? {
        switch format {
        case .forTime:
            return capTime
        case .amrap:
            return capTime ?? 0
        case .emom, .intervals:
            guard isCyclic else { return 0 }
            return hasManualBlock ? nil : cycleLength * Double(rounds)
        }
    }
}
