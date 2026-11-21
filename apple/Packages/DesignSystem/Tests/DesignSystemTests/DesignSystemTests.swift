import Testing
import DesignSystem

@Suite struct DesignSystemTests {
    @Test func moduleNameIsStable() {
        #expect(DesignSystem.moduleName == "DesignSystem")
    }
}
