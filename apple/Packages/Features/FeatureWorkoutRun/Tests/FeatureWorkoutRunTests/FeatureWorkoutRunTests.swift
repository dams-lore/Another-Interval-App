import Foundation
import Testing
import Domain
import TestSupport
@testable import FeatureWorkoutRun

@Suite struct RunFormatTests {
    @Test func elapsedRoundsDown() {
        #expect(RunFormat.elapsed(82.9) == "01:22")
        #expect(RunFormat.elapsed(0) == "00:00")
        #expect(RunFormat.elapsed(-5) == "00:00")
    }

    @Test func remainingRoundsUp() {
        #expect(RunFormat.remaining(82.1) == "01:23")
        #expect(RunFormat.remaining(0.2) == "00:01")
        #expect(RunFormat.remaining(3600) == "60:00")
    }
}

@MainActor @Suite struct RunViewModelTests {
    private func makeWorkout() -> Workout {
        Workout(
            name: "Breakfast Club", format: .intervals,
            steps: [
                Step(type: .time, movement: "Run", value: 90),
                Step(type: .time, movement: "Rest", value: 30),
            ],
            rounds: 4
        )
    }

    private func makeModel(_ clock: TestClock) -> RunViewModel {
        RunViewModel(workout: makeWorkout(), clock: clock, countdown: 0)
    }

    @Test func showsBlockTimerAndLabels() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        clock.advance(by: 10)
        model.refresh()
        #expect(model.mainTimerText == "01:20")
        #expect(model.totalTimerText == "00:10")
        #expect(model.blockTitle == "Run")
        #expect(model.blockCounterText == "BLOCK 1 / 2")
        #expect(model.roundText == "R1/4")
        #expect(model.overallProgress?.done == 0)
        #expect(model.overallProgress?.total == 8)
    }

    @Test func skipMovesToRestBlock() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        clock.advance(by: 5)
        model.skip()
        #expect(model.blockTitle == "Rest")
        #expect(model.overallProgress?.done == 1)
    }

    @Test func pauseFreezesTheTimer() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        clock.advance(by: 10)
        model.togglePause()
        clock.advance(by: 100)
        model.refresh()
        #expect(model.state.phase == .paused)
        #expect(model.totalTimerText == "00:10")
        model.togglePause()
        #expect(model.state.phase == .running)
    }

    @Test func stopFinishesTheSession() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        clock.advance(by: 20)
        model.stop()
        #expect(model.isFinished)
    }

    @Test func blockProgressIsBetweenZeroAndOne() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        clock.advance(by: 45)
        model.refresh()
        #expect(model.blockProgress == 0.5)
    }
}

@Suite struct StepFormatTests {
    @Test func formatsRepsCaloriesAndDistances() {
        #expect(StepFormat.line(for: Step(type: .reps, movement: "Burpees Over Row", value: 15)) == "15 Burpees Over Row")
        #expect(StepFormat.line(for: Step(type: .reps, movement: "Row", value: 20, unit: "cal")) == "20 cal Row")
        #expect(StepFormat.line(for: Step(type: .distance, movement: "Run", value: 400, unit: "m")) == "400 m Run")
        #expect(StepFormat.line(for: Step(type: .reps, movement: "Thrusters", value: 21, weight: 43)) == "21 Thrusters (43 kg)")
    }
}

@MainActor @Suite struct EveryXRunTests {
    private func workout() -> Workout {
        Workout(
            name: "EMF RX - DARK ZONE", format: .emom,
            steps: [
                Step(type: .reps, movement: "Row", value: 20, unit: "cal"),
                Step(type: .reps, movement: "Burpees Over Row", value: 15),
            ],
            rounds: 6, intervalSeconds: 300
        )
    }

    @Test func showsTheTasksOfTheInterval() {
        let clock = TestClock()
        let model = RunViewModel(workout: workout(), clock: clock, countdown: 0)
        model.start()
        clock.advance(by: 60)
        model.refresh()
        #expect(model.blockTitle == "Every 5:00")
        #expect(model.blockCounterText == "INTERVALLE 1 / 6")
        #expect(model.blockLines == ["20 cal Row", "15 Burpees Over Row"])
        #expect(model.mainTimerText == "04:00")
    }

    @Test func nextIntervalStartsAutomatically() {
        let clock = TestClock()
        let model = RunViewModel(workout: workout(), clock: clock, countdown: 0)
        model.start()
        clock.advance(by: 301)
        model.refresh()
        #expect(model.blockCounterText == "INTERVALLE 2 / 6")
    }
}

@MainActor @Suite struct ManualBlocksRunTests {
    private func workout() -> Workout {
        Workout(
            name: "Chipper", format: .intervals,
            steps: [
                Step(type: .distance, movement: "Run", value: 400, unit: "m"),
                Step(type: .reps, movement: "Burpees", value: 15),
            ],
            rounds: 2
        )
    }

    @Test func manualBlocksCountUpAndAdvanceOnDemand() {
        let clock = TestClock()
        let model = RunViewModel(workout: workout(), clock: clock, countdown: 0)
        model.start()
        clock.advance(by: 65)
        model.refresh()
        #expect(model.blockTitle == "Run")
        #expect(model.mainTimerText == "01:05")
        #expect(model.advanceLabel == "✓  Bloc terminé")
        #expect(model.blockLines == ["400 m Run"])
        model.advance()
        #expect(model.blockTitle == "Burpees")
        #expect(model.mainTimerText == "00:00")
        #expect(model.overallProgress?.done == 1)
        #expect(model.overallProgress?.total == 4)
    }
}

@MainActor @Suite struct RunReportTests {
    @Test func aRunLongEnoughIsReportedOnce() {
        let clock = TestClock()
        let reported = ReportCollector()
        let workout = Workout(name: "Fran", format: .forTime, steps: [Step(type: .reps, movement: "Thrusters", value: 21)])
        let model = RunViewModel(workout: workout, clock: clock, countdown: 0, onFinished: { reported.items.append($0) })
        model.start()
        clock.advance(by: 120)
        model.refresh()
        model.completeRound()
        model.stop()
        model.refresh()
        #expect(reported.items.count == 1)
        #expect(reported.items.first?.duration == 120)
        #expect(reported.items.first?.roundsCompleted == 1)
    }

    @Test func aVeryShortRunIsNotReported() {
        let clock = TestClock()
        let reported = ReportCollector()
        let workout = Workout(name: "Fran", format: .forTime, steps: [Step(type: .reps, movement: "Thrusters", value: 21)])
        let model = RunViewModel(workout: workout, clock: clock, countdown: 0, onFinished: { reported.items.append($0) })
        model.start()
        clock.advance(by: 2)
        model.stop()
        #expect(reported.items.isEmpty)
    }
}

@MainActor @Suite struct RunGuidanceTests {
    private func makeModel(_ clock: TestClock, _ guidance: RecordingGuidanceOutput) -> RunViewModel {
        let workout = Workout(
            name: "Tabata", format: .intervals,
            steps: [Step(type: .time, movement: "Work", value: 30), Step(type: .time, movement: "Rest", value: 10)],
            rounds: 1
        )
        return RunViewModel(workout: workout, clock: clock, countdown: 5, guidance: guidance)
    }

    @Test func playsCountdownGoWarningAndBlockEnd() {
        let clock = TestClock()
        let guidance = RecordingGuidanceOutput()
        let model = makeModel(clock, guidance)
        model.start()
        for _ in 0..<80 {          // 40 s par pas de 0,5 s
            clock.advance(by: 0.5)
            model.refresh()
        }
        #expect(guidance.cues == [
            .countdownTick(3), .countdownTick(2), .countdownTick(1),
            .go, .tenSecondsWarning, .blockEnd,
        ])
    }

    @Test func refreshingTwiceDoesNotReplayACue() {
        let clock = TestClock()
        let guidance = RecordingGuidanceOutput()
        let model = makeModel(clock, guidance)
        model.start()
        clock.advance(by: 5)
        model.refresh()
        model.refresh()
        model.refresh()
        #expect(guidance.cues.filter { $0 == .go }.count == 1)
    }

    @Test func stopPlaysSessionEnd() {
        let clock = TestClock()
        let guidance = RecordingGuidanceOutput()
        let model = makeModel(clock, guidance)
        model.start()
        clock.advance(by: 10)
        model.refresh()
        model.stop()
        #expect(guidance.cues.last == .sessionEnd)
    }

    @Test func noGuidanceIsFine() {
        let clock = TestClock()
        let model = RunViewModel(workout: DemoWorkoutFixture.simple, clock: clock, countdown: 0)
        model.start()
        clock.advance(by: 1)
        model.refresh()
        #expect(model.state.phase == .running)
    }
}

enum DemoWorkoutFixture {
    static let simple = Workout(name: "Simple", format: .forTime, steps: [Step(type: .reps, movement: "Squats", value: 10)])
}
