import Foundation
import Testing
import Domain
import TestSupport
import TimerEngine

private let t0 = Date(timeIntervalSince1970: 1_000)
private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }
private func near(_ value: TimeInterval?, _ expected: TimeInterval) -> Bool {
    guard let value else { return false }
    return abs(value - expected) < 0.001
}

@Suite struct RunPhaseTests {
    @Test func onlyIdleAndFinishedAreInactive() {
        #expect(RunPhase.idle.isActive == false)
        #expect(RunPhase.finished.isActive == false)
        #expect(RunPhase.countdown.isActive)
        #expect(RunPhase.running.isActive)
        #expect(RunPhase.paused.isActive)
    }
}

@Suite struct ForTimeTests {
    @Test func idleBeforeStart() {
        let engine = TimerEngine(configuration: .forTime())
        #expect(engine.state(at: at(5)).phase == .idle)
    }

    @Test func countdownThenRunning() {
        var engine = TimerEngine(configuration: .forTime(countdown: 10))
        engine.start(at: at(0))
        let during = engine.state(at: at(4))
        #expect(during.phase == .countdown)
        #expect(during.countdownRemaining == 6)
        let running = engine.state(at: at(70))
        #expect(running.phase == .running)
        #expect(running.elapsed == 60)
    }

    @Test func pauseFreezesTimeAndResumeContinues() {
        var engine = TimerEngine(configuration: .forTime(countdown: 10))
        engine.start(at: at(0))
        engine.pause(at: at(20))
        #expect(engine.state(at: at(40)).phase == .paused)
        #expect(engine.state(at: at(40)).elapsed == 10)
        engine.resume(at: at(50))
        let resumed = engine.state(at: at(60))
        #expect(resumed.phase == .running)
        #expect(resumed.elapsed == 20)
    }

    @Test func capEndsTheSession() {
        var engine = TimerEngine(configuration: .forTime(cap: 600, countdown: 0))
        engine.start(at: at(0))
        #expect(engine.state(at: at(599)).phase == .running)
        let end = engine.state(at: at(700))
        #expect(end.phase == .finished)
        #expect(end.elapsed == 600)
    }

    @Test func manualFinishFreezesElapsed() {
        var engine = TimerEngine(configuration: .forTime(countdown: 0))
        engine.start(at: at(0))
        engine.finish(at: at(100))
        let later = engine.state(at: at(500))
        #expect(later.phase == .finished)
        #expect(later.elapsed == 100)
    }

    @Test func startTwiceAndPauseBeforeStartAreIgnored() {
        var engine = TimerEngine(configuration: .forTime(countdown: 0))
        engine.pause(at: at(0))
        #expect(engine.state(at: at(1)).phase == .idle)
        engine.start(at: at(0))
        engine.start(at: at(50))
        #expect(engine.state(at: at(60)).elapsed == 60)
    }

    @Test func worksWithTestClock() {
        let clock = TestClock()
        var engine = TimerEngine(configuration: .forTime(countdown: 0))
        engine.start(at: clock.now())
        clock.advance(by: 42)
        #expect(engine.state(at: clock.now()).elapsed == 42)
    }
}

@Suite struct AmrapTests {
    @Test func endsAtDurationAndCountsRounds() {
        var engine = TimerEngine(configuration: .amrap(duration: 600, countdown: 0))
        engine.start(at: at(0))
        engine.completeRound(at: at(100))
        engine.completeRound(at: at(200))
        let running = engine.state(at: at(599))
        #expect(running.phase == .running)
        #expect(near(running.totalRemaining, 1))
        #expect(running.roundsCompleted == 2)
        let end = engine.state(at: at(600))
        #expect(end.phase == .finished)
        #expect(end.roundsCompleted == 2)
    }

    @Test func roundsAreNotCountedBeforeRunning() {
        var engine = TimerEngine(configuration: .amrap(duration: 600, countdown: 10))
        engine.start(at: at(0))
        engine.completeRound(at: at(5))
        #expect(engine.state(at: at(20)).roundsCompleted == 0)
    }
}

@Suite struct EmomTests {
    @Test func blocksFollowTheMinute() {
        var engine = TimerEngine(configuration: .emom(rounds: 3, countdown: 0))
        engine.start(at: at(0))
        let first = engine.state(at: at(0))
        #expect(first.roundIndex == 0)
        #expect(near(first.blockRemaining, 60))
        let second = engine.state(at: at(61))
        #expect(second.roundIndex == 1)
        #expect(near(second.blockElapsed, 1))
    }

    @Test func endsAfterLastMinute() {
        var engine = TimerEngine(configuration: .emom(rounds: 3, countdown: 0))
        engine.start(at: at(0))
        let end = engine.state(at: at(180))
        #expect(end.phase == .finished)
        #expect(end.roundsCompleted == 3)
    }

    @Test func skipJumpsToNextMinute() {
        var engine = TimerEngine(configuration: .emom(rounds: 3, countdown: 0))
        engine.start(at: at(0))
        engine.skip(at: at(10))
        let state = engine.state(at: at(10))
        #expect(state.roundIndex == 1)
        #expect(near(state.blockRemaining, 60))
    }
}

@Suite struct IntervalsTests {
    @Test func walksThroughWorkAndRest() {
        var engine = TimerEngine(configuration: .intervals(cycle: [30, 10], rounds: 2, countdown: 0))
        engine.start(at: at(0))
        let rest = engine.state(at: at(35))
        #expect(rest.roundIndex == 0)
        #expect(rest.blockIndex == 1)
        #expect(near(rest.blockRemaining, 5))
        let secondRound = engine.state(at: at(45))
        #expect(secondRound.roundIndex == 1)
        #expect(secondRound.blockIndex == 0)
        #expect(near(secondRound.blockElapsed, 5))
    }

    @Test func skipMovesToNextBlock() {
        var engine = TimerEngine(configuration: .intervals(cycle: [30, 10], rounds: 2, countdown: 0))
        engine.start(at: at(0))
        engine.skip(at: at(5))
        let state = engine.state(at: at(5))
        #expect(state.blockIndex == 1)
        #expect(near(state.blockRemaining, 10))
    }

    @Test func endsAfterLastRound() {
        var engine = TimerEngine(configuration: .intervals(cycle: [30, 10], rounds: 2, countdown: 0))
        engine.start(at: at(0))
        #expect(engine.state(at: at(79)).phase == .running)
        #expect(engine.state(at: at(80)).phase == .finished)
    }

    @Test func skipIsIgnoredForForTime() {
        var engine = TimerEngine(configuration: .forTime(countdown: 0))
        engine.start(at: at(0))
        engine.skip(at: at(10))
        #expect(engine.state(at: at(10)).elapsed == 10)
    }
}

@Suite struct ConfigurationTests {
    @Test func intervalsConfigurationFromWorkout() {
        let workout = Workout(
            name: "Tabata", format: .intervals,
            steps: [
                Step(type: .time, movement: "Work", value: 20),
                Step(type: .time, movement: "Rest", value: 10),
                Step(type: .reps, movement: "Ignoré", value: 5),
            ],
            rounds: 8
        )
        let config = RunConfiguration(workout: workout, countdown: 5)
        #expect(config.cycle == [20, 10])
        #expect(config.rounds == 8)
        #expect(config.totalDuration == 240)
        #expect(config.countdown == 5)
    }

    @Test func emomConfigurationFromWorkout() {
        let workout = Workout(name: "E", format: .emom, steps: [Step(type: .reps, movement: "Squats", value: 10)], rounds: 12)
        #expect(RunConfiguration(workout: workout).totalDuration == 720)
    }
}
