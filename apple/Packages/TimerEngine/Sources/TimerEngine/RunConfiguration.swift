import Foundation
import Domain

/// Paramètres d'exécution d'une séance, indépendants de l'UI.
/// - `cycle` : durée de chaque bloc d'un tour (EMOM : un seul bloc de `interval`).
public struct RunConfiguration: Sendable, Equatable {
    public var format: WorkoutFormat
    public var countdown: TimeInterval
    public var cycle: [TimeInterval]
    public var rounds: Int
    public var capTime: TimeInterval?

    public init(
        format: WorkoutFormat,
        countdown: TimeInterval = 10,
        cycle: [TimeInterval] = [],
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

    public static func intervals(cycle: [TimeInterval], rounds: Int, countdown: TimeInterval = 10) -> RunConfiguration {
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
            self.init(format: .emom, countdown: countdown, cycle: [60], rounds: workout.rounds ?? 1)
        case .intervals:
            let cycle = workout.steps.filter { $0.type == .time && $0.value > 0 }.map(\.value)
            self.init(format: .intervals, countdown: countdown, cycle: cycle, rounds: workout.rounds ?? 1)
        }
    }

    var cycleLength: TimeInterval { cycle.reduce(0, +) }

    /// Vrai pour les formats découpés en blocs de durée fixe (EMOM, fractionné).
    var isCyclic: Bool {
        (format == .emom || format == .intervals) && cycleLength > 0
    }

    /// Durée totale de la partie chronométrée (hors compte à rebours). `nil` = pas de limite.
    public var totalDuration: TimeInterval? {
        switch format {
        case .forTime:
            return capTime
        case .amrap:
            return capTime ?? 0
        case .emom, .intervals:
            return isCyclic ? cycleLength * Double(rounds) : 0
        }
    }
}
