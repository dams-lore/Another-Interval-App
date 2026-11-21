import Foundation
import Testing
import Domain

@Suite struct DomainTests {
    @Test func workoutFormatsAreStable() {
        #expect(WorkoutFormat.allCases.map(\.rawValue) == ["forTime", "amrap", "emom", "intervals"])
    }

    @Test func workoutFormatRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(WorkoutFormat.emom)
        #expect(try JSONDecoder().decode(WorkoutFormat.self, from: data) == .emom)
    }

    @Test func systemClockReturnsCurrentTime() {
        let before = Date()
        let now = SystemClock().now()
        #expect(now >= before)
    }
}

@Suite struct WorkoutTests {
    private func step(_ type: StepType = .time, value: Double = 30) -> Step {
        Step(type: type, movement: "Burpees", value: value)
    }

    @Test func validWorkoutPasses() throws {
        let workout = Workout(name: "Fran", format: .forTime, steps: [step(.reps, value: 21)])
        try workout.validate()
    }

    @Test func emptyNameIsRejected() {
        let workout = Workout(name: "  ", format: .forTime, steps: [step()])
        #expect(throws: DomainError.self) { try workout.validate() }
    }

    @Test func workoutWithoutStepsIsRejected() {
        let workout = Workout(name: "Vide", format: .forTime)
        #expect(throws: DomainError.self) { try workout.validate() }
    }

    @Test func amrapRequiresPositiveCap() {
        let bad = Workout(name: "Cindy", format: .amrap, steps: [step()], capTime: 0)
        #expect(throws: DomainError.self) { try bad.validate() }
        let good = Workout(name: "Cindy", format: .amrap, steps: [step()], capTime: 1200)
        #expect((try? good.validate()) != nil)
    }

    @Test func emomRequiresRounds() {
        let bad = Workout(name: "E", format: .emom, steps: [step()])
        #expect(throws: DomainError.self) { try bad.validate() }
        let good = Workout(name: "E", format: .emom, steps: [step()], rounds: 10)
        #expect((try? good.validate()) != nil)
    }

    @Test func intervalsAcceptUntimedBlocks() {
        let repsOnly = Workout(name: "I", format: .intervals, steps: [step(.reps, value: 10)])
        #expect((try? repsOnly.validate()) != nil)
        let timed = Workout(name: "I", format: .intervals, steps: [step(.time, value: 30)])
        #expect((try? timed.validate()) != nil)
    }

    @Test func intervalSecondsSurvivesJSON() throws {
        let workout = Workout(name: "Every 5:00", format: .emom, steps: [step(.reps, value: 15)], rounds: 6, intervalSeconds: 300)
        let decoded = try JSONDecoder().decode(Workout.self, from: JSONEncoder().encode(workout))
        #expect(decoded.intervalSeconds == 300)
    }

    @Test func workoutRoundTripsThroughJSON() throws {
        let workout = Workout(
            name: "Murph", format: .forTime, sport: "crossfit",
            steps: [step(.distance, value: 1600)], source: .photoImport
        )
        let data = try JSONEncoder().encode(workout)
        let decoded = try JSONDecoder().decode(Workout.self, from: data)
        #expect(decoded == workout)
    }
}

@Suite struct PaceTests {
    @Test func paceInSecondsPerKilometer() {
        #expect(Pace.secondsPerKilometer(distanceMeters: 1000, duration: 300) == 300)
        #expect(Pace.secondsPerKilometer(distanceMeters: 500, duration: 150) == 300)
    }

    @Test func speedInKilometersPerHour() {
        #expect(Pace.kilometersPerHour(distanceMeters: 1000, duration: 360) == 10)
    }

    @Test func zeroInputsGiveNil() {
        #expect(Pace.secondsPerKilometer(distanceMeters: 0, duration: 10) == nil)
        #expect(Pace.kilometersPerHour(distanceMeters: 100, duration: 0) == nil)
    }
}

@Suite struct GuidanceCueTests {
    @Test func cuesAreComparable() {
        #expect(GuidanceCue.countdownTick(3) == .countdownTick(3))
        #expect(GuidanceCue.countdownTick(3) != .countdownTick(2))
        #expect(GuidanceCue.go != .blockEnd)
    }
}
