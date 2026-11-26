import Foundation

/// Transforme la photo d'une séance en `Workout`. Implémenté dans DataLayer (IA), faux dans les tests.
public protocol WorkoutImportService: Sendable {
    func importWorkout(imageData: Data, mimeType: String) async throws -> Workout
}
