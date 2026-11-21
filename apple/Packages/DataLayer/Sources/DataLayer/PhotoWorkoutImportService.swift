import Foundation
import Domain
import Backend

/// Import de séance par photo : IA (Backend) → mapping → validation (Domain).
public struct PhotoWorkoutImportService: WorkoutImportService {
    private let client: AnthropicImportClient
    private let clock: any AppClock

    public init(client: AnthropicImportClient, clock: any AppClock = SystemClock()) {
        self.client = client
        self.clock = clock
    }

    public func importWorkout(imageData: Data, mimeType: String) async throws -> Workout {
        let now = clock.now()
        let today = Self.dateString(now)
        do {
            let dto = try await client.importWorkout(imageData: imageData, mimeType: mimeType, today: today)
            let workout = try WorkoutImportMapper.workout(from: dto, defaultName: "WOD \(today)", now: now)
            try workout.validate()
            return workout
        } catch let error as ImportError {
            throw Self.domainError(for: error)
        } catch is URLError {
            throw DomainError.offline
        }
    }

    static func domainError(for error: ImportError) -> DomainError {
        switch error {
        case .missingAPIKey:
            .validation("Clé API manquante : voir le fichier Secrets.xcconfig.")
        case .http(let status, let message):
            status == 401 ? .validation("Clé API refusée (\(message)).") : .validation("Erreur du service d'IA (\(status)) : \(message)")
        case .invalidResponse, .invalidJSON:
            .validation("L'IA n'a pas renvoyé une séance lisible. Essaie avec une photo plus nette.")
        }
    }

    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
