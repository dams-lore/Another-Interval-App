import Testing
@testable import AnotherInterval

@Suite struct AnotherIntervalTests {
    @Test func rootViewCanBeCreated() {
        _ = RootView()
    }

    @Test func demoWorkoutIsValid() throws {
        try DemoWorkout.breakfastClub.validate()
    }
}
