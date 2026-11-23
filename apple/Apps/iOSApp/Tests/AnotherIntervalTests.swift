import Foundation
import Testing
import Domain
import TestSupport
@testable import AnotherInterval

// RootView est une vue SwiftUI (isolée sur le MainActor) : les tests doivent l'être aussi.
@MainActor @Suite struct AnotherIntervalTests {
    private func makeStore(defaults: UserDefaults = UserDefaults(suiteName: "tests-\(UUID().uuidString)")!) -> LibraryStore {
        LibraryStore(workoutRepository: InMemoryWorkoutRepository(), sessionRepository: InMemorySessionRepository(), defaults: defaults)
    }

    @Test func rootViewCanBeCreated() {
        _ = RootView(store: makeStore())
    }

    @Test func allDemoWorkoutsAreValid() throws {
        for workout in DemoWorkout.all {
            try workout.validate()
        }
    }

    @Test func demoWorkoutsAreSeededOnlyOnce() async {
        let defaults = UserDefaults(suiteName: "tests-\(UUID().uuidString)")!
        let store = makeStore(defaults: defaults)
        await store.load()
        #expect(store.workouts.count == DemoWorkout.all.count)
        await store.load()
        #expect(store.workouts.count == DemoWorkout.all.count)
    }

    @Test func savedAndDeletedWorkoutsAreReflected() async {
        let store = makeStore()
        await store.load()
        let imported = Workout(name: "Importée", format: .forTime, steps: [Step(type: .reps, movement: "Squats", value: 10)], source: .photoImport)
        await store.save(imported)
        #expect(store.workouts.contains { $0.name == "Importée" })
        await store.delete(imported)
        #expect(!store.workouts.contains { $0.name == "Importée" })
    }

    @Test func recordedSessionsAppearInTheHistory() async {
        let store = makeStore()
        await store.load()
        let record = SessionRecord(workout: DemoWorkout.darkZone, startedAt: Date(), duration: 900)
        await store.record(record)
        #expect(store.sessions.count == 1)
        await store.delete(record)
        #expect(store.sessions.isEmpty)
    }

    @Test func subtitlesDescribeEachFormat() {
        #expect(RootView.subtitle(of: DemoWorkout.darkZone) == "Every 5:00 × 6 · 4 étapes")
        #expect(RootView.subtitle(of: DemoWorkout.amrap) == "AMRAP 12 min")
        #expect(RootView.subtitle(of: DemoWorkout.fran) == "For Time · cap 10 min")
    }

    @Test func historyRowsSummarizeTheResult() {
        let sets = [SetResult(setIndex: 0, completionTime: 190, interval: 300), SetResult(setIndex: 1, completionTime: nil, interval: 300)]
        let every = SessionRecord(workout: DemoWorkout.darkZone, startedAt: Date(), duration: 600, setResults: sets)
        #expect(HistoryView.resultText(for: every) == "1/6 sets")
        let plain = SessionRecord(workout: DemoWorkout.fran, startedAt: Date(), duration: 754)
        #expect(HistoryView.resultText(for: plain) == "12:34")
    }
}
