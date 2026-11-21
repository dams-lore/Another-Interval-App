import Foundation
import Observation
import Domain

/// ViewModel de l'import par photo : ne connaît que le protocole `WorkoutImportService`.
@MainActor @Observable
public final class PhotoImportViewModel {
    public enum Status: Equatable {
        case idle
        case analysing
        case review(Workout)
        case failed(String)
    }

    public private(set) var status: Status = .idle
    private let service: any WorkoutImportService

    public init(service: any WorkoutImportService) {
        self.service = service
    }

    public func importPhoto(data: Data, mimeType: String = "image/jpeg") async {
        status = .analysing
        do {
            let workout = try await service.importWorkout(imageData: data, mimeType: mimeType)
            status = .review(workout)
        } catch {
            status = .failed(Self.message(for: error))
        }
    }

    public func fail(_ message: String) { status = .failed(message) }

    public func reset() { status = .idle }

    static func message(for error: Error) -> String {
        guard let error = error as? DomainError else { return "Une erreur est survenue. Réessaie." }
        switch error {
        case .validation(let message): return message
        case .offline: return "Pas de connexion Internet. Réessaie une fois en ligne."
        case .quotaExceeded: return "Tu as utilisé tous tes imports gratuits."
        case .consentRequired: return "Ton accord est nécessaire pour envoyer la photo à l'IA."
        case .premiumRequired: return "Cette fonction demande l'abonnement premium."
        case .notAuthenticated: return "Connecte-toi pour importer une séance."
        case .notFound: return "Séance introuvable."
        }
    }
}
