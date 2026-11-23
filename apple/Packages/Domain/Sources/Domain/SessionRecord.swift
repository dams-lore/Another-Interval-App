import Foundation

/// Une séance réellement effectuée (historique). Contient une copie figée de la séance :
/// l'historique ne change pas si la séance est modifiée ensuite.
public struct SessionRecord: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var workout: Workout
    public var startedAt: Date
    public var duration: TimeInterval
    public var roundsCompleted: Int
    /// Résultats set par set (séances « Every X × N ») ; vide pour les autres formats.
    public var setResults: [SetResult]

    public init(
        id: UUID = UUID(),
        workout: Workout,
        startedAt: Date,
        duration: TimeInterval,
        roundsCompleted: Int = 0,
        setResults: [SetResult] = []
    ) {
        self.id = id
        self.workout = workout
        self.startedAt = startedAt
        self.duration = duration
        self.roundsCompleted = roundsCompleted
        self.setResults = setResults
    }

    public var completedSets: Int { setResults.filter(\.isCompleted).count }

    /// Statistiques set par set, si la séance en a.
    public var summary: EveryXSummary? {
        guard !setResults.isEmpty else { return nil }
        return EveryXSummary(results: setResults, totalSets: max(workout.rounds ?? 0, setResults.count))
    }
}
