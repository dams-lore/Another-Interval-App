import Foundation

/// Temps passé sur une étape d'un set (« row 0:53 »).
public struct StepSplit: Sendable, Codable, Equatable {
    public var stepIndex: Int
    public var movement: String
    public var duration: TimeInterval

    public init(stepIndex: Int, movement: String, duration: TimeInterval) {
        self.stepIndex = stepIndex
        self.movement = movement
        self.duration = duration
    }
}

/// Résultat d'un set (un intervalle). `completionTime == nil` : set non fini à la fin de l'intervalle.
public struct SetResult: Sendable, Codable, Equatable, Identifiable {
    public var setIndex: Int
    public var splits: [StepSplit]
    public var completionTime: TimeInterval?
    public var interval: TimeInterval

    public var id: Int { setIndex }
    public var isCompleted: Bool { completionTime != nil }

    /// Repos = temps gagné sur l'intervalle.
    public var rest: TimeInterval? { completionTime.map { max(0, interval - $0) } }

    public init(setIndex: Int, splits: [StepSplit] = [], completionTime: TimeInterval?, interval: TimeInterval) {
        self.setIndex = setIndex
        self.splits = splits
        self.completionTime = completionTime
        self.interval = interval
    }
}

/// Statistiques de fin de séance (règles métier pures).
public struct EveryXSummary: Sendable, Equatable {
    public let results: [SetResult]
    public let totalSets: Int

    public init(results: [SetResult], totalSets: Int) {
        self.results = results
        self.totalSets = totalSets
    }

    private var times: [TimeInterval] { results.compactMap(\.completionTime) }

    public var completedCount: Int { times.count }
    public var averageTime: TimeInterval? { times.isEmpty ? nil : times.reduce(0, +) / Double(times.count) }
    public var bestTime: TimeInterval? { times.min() }
    public var worstTime: TimeInterval? { times.max() }

    /// Écart entre le pire et le meilleur set.
    public var spread: TimeInterval? {
        guard let best = bestTime, let worst = worstTime else { return nil }
        return worst - best
    }
}
