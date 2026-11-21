import Testing
import TimerEngine

@Suite struct TimerEngineTests {
    @Test func onlyIdleAndFinishedAreInactive() {
        #expect(RunPhase.idle.isActive == false)
        #expect(RunPhase.finished.isActive == false)
        #expect(RunPhase.countdown.isActive)
        #expect(RunPhase.running.isActive)
        #expect(RunPhase.paused.isActive)
    }
}
