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

@Suite struct EveryXSummaryTests {
    private func result(_ index: Int, _ time: TimeInterval?) -> SetResult {
        SetResult(setIndex: index, completionTime: time, interval: 300)
    }

    @Test func computesAverageBestWorstAndSpread() {
        let summary = EveryXSummary(results: [result(0, 195), result(1, 190), result(2, 202), result(3, 205)], totalSets: 4)
        #expect(summary.completedCount == 4)
        #expect(summary.bestTime == 190)
        #expect(summary.worstTime == 205)
        #expect(summary.spread == 15)
        #expect(summary.averageTime == 198)
    }

    @Test func unfinishedSetsAreIgnoredInStats() {
        let summary = EveryXSummary(results: [result(0, 200), result(1, nil)], totalSets: 2)
        #expect(summary.completedCount == 1)
        #expect(summary.bestTime == 200)
    }

    @Test func noCompletedSetGivesNoStats() {
        let summary = EveryXSummary(results: [result(0, nil)], totalSets: 1)
        #expect(summary.averageTime == nil)
        #expect(summary.spread == nil)
    }

    @Test func restIsTheTimeSavedOnTheInterval() {
        #expect(result(0, 195).rest == 105)
        #expect(result(0, nil).rest == nil)
        #expect(result(0, 400).rest == 0)
    }
}
