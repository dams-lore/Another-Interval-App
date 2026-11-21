import Testing
import Backend

@Suite struct BackendTests {
    @Test func moduleNameIsStable() {
        #expect(Backend.moduleName == "Backend")
    }
}
