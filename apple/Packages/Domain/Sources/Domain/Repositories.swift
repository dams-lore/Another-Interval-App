import Foundation

/// Séances enregistrées. Tout passe par le stockage local (l'app marche hors ligne) ;
/// la synchronisation viendra plus tard derrière le même protocole.
public protocol WorkoutRepository: Sendable {
    func all() async throws -> [Workout]
    func save(_ workout: Workout) async throws
    func delete(id: Workout.ID) async throws
}

/// Historique des séances effectuées.
public protocol SessionRepository: Sendable {
    func all() async throws -> [SessionRecord]
    func save(_ record: SessionRecord) async throws
    func delete(id: SessionRecord.ID) async throws
}
