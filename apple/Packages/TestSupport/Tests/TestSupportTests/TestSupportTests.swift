import Testing
import TestSupport

@Suite struct TestSupportTests {
    @Test func clockAdvancesOnlyWhenAsked() {
        let clock = TestClock()
        let start = clock.now()
        #expect(clock.now() == start)
        clock.advance(by: 90)
        #expect(clock.now().timeIntervalSince(start) == 90)
    }
}
