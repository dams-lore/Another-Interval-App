import Foundation
import Domain

/// Où l'app range ses données locales.
public enum LocalStorage {
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AnotherInterval", isDirectory: true)
    }
}

/// Séances enregistrées dans `workouts.json`. Une suppression est « logique » (`deletedAt`) pour pouvoir
/// la propager plus tard à la synchronisation.
public struct FileWorkoutRepository: WorkoutRepository {
    private let store: JSONFileStore<Workout>

    public init(directory: URL) {
        store = JSONFileStore(url: directory.appendingPathComponent("workouts.json"))
    }

    public func all() async throws -> [Workout] {
        await store.all().filter { $0.deletedAt == nil }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func save(_ workout: Workout) async throws {
        try await store.upsert(workout)
    }

    public func delete(id: Workout.ID) async throws {
        guard var workout = await store.all().first(where: { $0.id == id }) else { return }
        workout.deletedAt = Date()
        workout.updatedAt = Date()
        try await store.upsert(workout)
    }
}

/// Historique des séances effectuées, dans `sessions.json`.
public struct FileSessionRepository: SessionRepository {
    private let store: JSONFileStore<SessionRecord>

    public init(directory: URL) {
        store = JSONFileStore(url: directory.appendingPathComponent("sessions.json"))
    }

    public func all() async throws -> [SessionRecord] {
        await store.all().sorted { $0.startedAt > $1.startedAt }
    }

    public func save(_ record: SessionRecord) async throws {
        try await store.upsert(record)
    }

    public func delete(id: SessionRecord.ID) async throws {
        try await store.remove(id: id)
    }
}
