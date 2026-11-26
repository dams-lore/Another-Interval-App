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
    @Test func intervalsConfigurationKeepsUntimedBlocksAsManual() {
        let workout = Workout(
            name: "Tabata", format: .intervals,
            steps: [
                Step(type: .time, movement: "Work", value: 20),
                Step(type: .time, movement: "Rest", value: 10),
                Step(type: .reps, movement: "Burpees", value: 5),
            ],
            rounds: 8
        )
        let config = RunConfiguration(workout: workout, countdown: 5)
        #expect(config.cycle == [20, 10, nil])
        #expect(config.rounds == 8)
        #expect(config.totalDuration == nil)   // un bloc manuel : pas de durée totale connue
        #expect(config.countdown == 5)
    }

    @Test func fullyTimedIntervalsHaveATotalDuration() {
        let workout = Workout(
            name: "Tabata", format: .intervals,
            steps: [Step(type: .time, movement: "Work", value: 20), Step(type: .time, movement: "Rest", value: 10)],
            rounds: 8
        )
        #expect(RunConfiguration(workout: workout).totalDuration == 240)
    }

    @Test func emomUsesTheWorkoutInterval() {
        let workout = Workout(
            name: "Every 5:00", format: .emom,
            steps: [Step(type: .reps, movement: "Row", value: 20)],
            rounds: 6, intervalSeconds: 300
        )
        let config = RunConfiguration(workout: workout)
        #expect(config.cycle == [300])
        #expect(config.totalDuration == 1800)
    }

    @Test func emomConfigurationFromWorkout() {
        let workout = Workout(name: "E", format: .emom, steps: [Step(type: .reps, movement: "Squats", value: 10)], rounds: 12)
        #expect(RunConfiguration(workout: workout).totalDuration == 720)
    }
}

@Suite struct RunEventDetectorTests {
    /// Fait avancer le moteur par pas de 0,5 s et collecte tous les événements.
    private func collect(_ configuration: RunConfiguration, until end: TimeInterval, skipAt: TimeInterval? = nil) -> [RunEvent] {
        var engine = TimerEngine(configuration: configuration)
        var detector = RunEventDetector()
        var events: [RunEvent] = []
        engine.start(at: at(0))
        var t: TimeInterval = 0
        while t <= end {
            if let skipAt, t == skipAt { engine.skip(at: at(t)) }
            events += detector.events(for: engine.state(at: at(t)))
            t += 0.5
        }
        return events
    }

    @Test func intervalsEmitEachEventOnce() {
        let config = RunConfiguration.intervals(cycle: [30, 10], rounds: 2, countdown: 5)
        let events = collect(config, until: 90)
        #expect(events == [
            .countdownTick(3), .countdownTick(2), .countdownTick(1),
            .go,
            .tenSecondsLeft,      // 10 s avant la fin du bloc de 30 s
            .blockEnded,          // début du repos de 10 s : pas d'alerte (bloc trop court)
            .blockEnded,          // tour 2
            .tenSecondsLeft,
            .blockEnded,
            .sessionFinished,
        ])
    }

    @Test func skipEmitsBlockEnded() {
        let config = RunConfiguration.intervals(cycle: [30, 10], rounds: 1, countdown: 0)
        let events = collect(config, until: 14.5, skipAt: 5)
        #expect(events == [.go, .blockEnded])
    }

    @Test func amrapWarnsTenSecondsBeforeCapAndFinishes() {
        let events = collect(.amrap(duration: 60, countdown: 0), until: 65)
        #expect(events == [.go, .tenSecondsLeft, .sessionFinished])
    }

    @Test func forTimeWithoutCapNeverWarns() {
        let events = collect(.forTime(countdown: 0), until: 120)
        #expect(events == [.go])
    }

    @Test func pausedStateEmitsNothing() {
        var engine = TimerEngine(configuration: .forTime(countdown: 0))
        var detector = RunEventDetector()
        engine.start(at: at(0))
        _ = detector.events(for: engine.state(at: at(1)))
        engine.pause(at: at(2))
        #expect(detector.events(for: engine.state(at: at(3))).isEmpty)
    }
}

@Suite struct ManualBlocksTests {
    /// Cycle : un bloc manuel (reps) puis un bloc chronométré de 10 s, 2 tours.
    private func makeEngine() -> TimerEngine {
        var engine = TimerEngine(configuration: .intervals(cycle: [nil, 10], rounds: 2, countdown: 0))
        engine.start(at: at(0))
        return engine
    }

    @Test func manualBlockHasNoRemainingTimeAndCountsUp() {
        let engine = makeEngine()
        let state = engine.state(at: at(5))
        #expect(state.blockIndex == 0)
        #expect(state.blockRemaining == nil)
        #expect(near(state.blockElapsed, 5))
        #expect(state.totalRemaining == nil)
    }

    @Test func manualBlockNeverEndsByItself() {
        let engine = makeEngine()
        let state = engine.state(at: at(3_000))
        #expect(state.phase == .running)
        #expect(state.blockIndex == 0)
    }

    @Test func skipEndsTheManualBlockThenTheTimedOneRunsOut() {
        var engine = makeEngine()
        engine.skip(at: at(8))
        let timed = engine.state(at: at(8))
        #expect(timed.blockIndex == 1)
        #expect(near(timed.blockRemaining, 10))
        let secondRound = engine.state(at: at(18))
        #expect(secondRound.roundIndex == 1)
        #expect(secondRound.blockIndex == 0)
        #expect(near(secondRound.blockElapsed, 0))
    }

    @Test func sessionFinishesWhenTheLastBlockIsDone() {
        var engine = makeEngine()
        engine.skip(at: at(8))        // bloc manuel 1
        // le bloc chronométré se termine à 18 s ; le bloc manuel du tour 2 est terminé à 25 s
        engine.skip(at: at(25))
        let state = engine.state(at: at(25))
        #expect(state.blockIndex == 1)
        #expect(engine.state(at: at(35)).phase == .finished)
        #expect(engine.state(at: at(35)).roundsCompleted == 2)
    }

    @Test func pauseDoesNotCountInManualBlockTime() {
        var engine = makeEngine()
        engine.pause(at: at(5))
        engine.resume(at: at(65))
        #expect(near(engine.state(at: at(70)).blockElapsed, 10))
    }
}

@Suite struct ManualBlockEventsTests {
    @Test func manualBlocksNeverWarnButSkipEmitsBlockEnded() {
        var engine = TimerEngine(configuration: .intervals(cycle: [nil, nil], rounds: 1, countdown: 0))
        var detector = RunEventDetector()
        engine.start(at: at(0))
        var events = detector.events(for: engine.state(at: at(0)))
        events += detector.events(for: engine.state(at: at(30)))
        engine.skip(at: at(31))
        events += detector.events(for: engine.state(at: at(31)))
        engine.skip(at: at(40))
        events += detector.events(for: engine.state(at: at(40)))
        #expect(events == [.go, .blockEnded, .sessionFinished])
    }
}
