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
