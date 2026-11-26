import Foundation
import Domain

/// Service d'import factice : renvoie un résultat prédéfini (tests sans réseau ni IA).
public struct FakeWorkoutImportService: WorkoutImportService {
    public var result: Result<Workout, DomainError>

    public init(result: Result<Workout, DomainError>) {
        self.result = result
    }

    public func importWorkout(imageData: Data, mimeType: String) async throws -> Workout {
        try result.get()
    }
}
