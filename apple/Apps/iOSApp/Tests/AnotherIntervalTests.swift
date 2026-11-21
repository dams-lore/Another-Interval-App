import Testing
@testable import AnotherInterval

// RootView est une vue SwiftUI (isolée sur le MainActor) : le test doit l'être aussi.
@MainActor @Suite struct AnotherIntervalTests {
    @Test func rootViewCanBeCreated() {
        _ = RootView()
    }

    @Test func allDemoWorkoutsAreValid() throws {
        for workout in DemoWorkout.all {
            try workout.validate()
        }
    }
}
