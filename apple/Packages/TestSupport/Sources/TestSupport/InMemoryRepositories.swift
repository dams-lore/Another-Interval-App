import Foundation
import Domain

/// Dépôt de séances en mémoire (tests sans disque).
public actor InMemoryWorkoutRepository: WorkoutRepository {
    private var items: [Workout]

    public init(_ items: [Workout] = []) { self.items = items }

    public func all() async throws -> [Workout] { items.filter { $0.deletedAt == nil } }

    public func save(_ workout: Workout) async throws {
        if let index = items.firstIndex(where: { $0.id == workout.id }) { items[index] = workout } else { items.append(workout) }
    }

    public func delete(id: Workout.ID) async throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].deletedAt = Date()
    }
}

/// Dépôt d'historique en mémoire (tests sans disque).
public actor InMemorySessionRepository: SessionRepository {
    private var items: [SessionRecord]

    public init(_ items: [SessionRecord] = []) { self.items = items }

    public func all() async throws -> [SessionRecord] { items.sorted { $0.startedAt > $1.startedAt } }

    public func save(_ record: SessionRecord) async throws {
        if let index = items.firstIndex(where: { $0.id == record.id }) { items[index] = record } else { items.append(record) }
    }

    public func delete(id: SessionRecord.ID) async throws { items.removeAll { $0.id == id } }
}
