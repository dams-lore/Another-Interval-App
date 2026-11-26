import Foundation
import Observation
import Domain
import DataLayer

/// Séances enregistrées et historique, chargés depuis le stockage local.
/// Les trois séances de démo sont ajoutées une seule fois, au premier lancement.
@MainActor @Observable
final class LibraryStore {
    private(set) var workouts: [Workout] = []
    private(set) var sessions: [SessionRecord] = []

    private let workoutRepository: any WorkoutRepository
    private let sessionRepository: any SessionRepository
    private let defaults: UserDefaults

    private static let seededKey = "demoWorkoutsSeeded"

    init(workoutRepository: any WorkoutRepository, sessionRepository: any SessionRepository, defaults: UserDefaults = .standard) {
        self.workoutRepository = workoutRepository
        self.sessionRepository = sessionRepository
        self.defaults = defaults
    }

    /// Stockage réel de l'app (fichiers JSON dans Application Support).
    static func live() -> LibraryStore {
        let directory = LocalStorage.defaultDirectory()
        return LibraryStore(
            workoutRepository: FileWorkoutRepository(directory: directory),
            sessionRepository: FileSessionRepository(directory: directory)
        )
    }

    func load() async {
        if !defaults.bool(forKey: Self.seededKey) {
            for workout in DemoWorkout.all {
                try? await workoutRepository.save(workout)
            }
            defaults.set(true, forKey: Self.seededKey)
        }
        await reload()
    }

    func save(_ workout: Workout) async {
        var updated = workout
        updated.updatedAt = Date()
        try? await workoutRepository.save(updated)
        await reload()
    }

    func delete(_ workout: Workout) async {
        try? await workoutRepository.delete(id: workout.id)
        await reload()
    }

    func record(_ session: SessionRecord) async {
        try? await sessionRepository.save(session)
        await reload()
    }

    func delete(_ session: SessionRecord) async {
        try? await sessionRepository.delete(id: session.id)
        await reload()
    }

    private func reload() async {
        workouts = (try? await workoutRepository.all()) ?? workouts
        sessions = (try? await sessionRepository.all()) ?? sessions
    }
}
