import Foundation

public enum WorkoutSource: String, Sendable, Codable, Equatable {
    case manual
    case photoImport
}

/// Modèle de séance. `id` généré côté client (requis par la sync).
public struct Workout: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var format: WorkoutFormat
    public var sport: String?
    public var steps: [Step]
    public var capTime: TimeInterval?
    public var rounds: Int?
    /// Durée de chaque intervalle pour « Every X × N » / EMOM (60 s si absent).
    public var intervalSeconds: TimeInterval?
    public var source: WorkoutSource
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        format: WorkoutFormat,
        sport: String? = nil,
        steps: [Step] = [],
        capTime: TimeInterval? = nil,
        rounds: Int? = nil,
        intervalSeconds: TimeInterval? = nil,
        source: WorkoutSource = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.sport = sport
        self.steps = steps
        self.capTime = capTime
        self.rounds = rounds
        self.intervalSeconds = intervalSeconds
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Règles de validité d'une séance avant de pouvoir la lancer.
    public func validate() throws {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            throw DomainError.validation("Le nom de la séance est vide.")
        }
        if steps.isEmpty {
            throw DomainError.validation("La séance n'a aucun bloc.")
        }
        switch format {
        case .forTime:
            break
        case .amrap:
            guard let capTime, capTime > 0 else {
                throw DomainError.validation("Un AMRAP demande une durée (time cap) positive.")
            }
        case .emom:
            guard let rounds, rounds > 0 else {
                throw DomainError.validation("Un EMOM demande un nombre de minutes positif.")
            }
        case .intervals:
            // Blocs chronométrés (travail / repos) ou manuels (reps, distance) : tout est accepté.
            break
        }
    }
}
