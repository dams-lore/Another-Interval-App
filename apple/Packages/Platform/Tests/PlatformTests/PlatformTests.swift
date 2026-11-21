import Testing
import Platform

@Suite struct PlatformTests {
    @Test func moduleNameIsStable() {
        #expect(Platform.moduleName == "Platform")
    }
}
