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
