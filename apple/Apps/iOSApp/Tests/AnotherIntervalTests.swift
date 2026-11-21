import Testing
@testable import AnotherInterval

@Suite struct AnotherIntervalTests {
    @Test func rootViewCanBeCreated() {
        _ = RootView()
    }
}
