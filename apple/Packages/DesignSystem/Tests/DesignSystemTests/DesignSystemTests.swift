import Testing
import DesignSystem

@Suite struct DesignSystemTests {
    @Test func moduleNameIsStable() {
        #expect(DesignSystem.moduleName == "DesignSystem")
    }
}

@Suite struct TokensTests {
    @Test func radiiMatchFigma() {
        #expect(DS.Radius.chip == 20)
        #expect(DS.Radius.badge == 12)
        #expect(DS.Radius.small == 14)
        #expect(DS.Radius.medium == 18)
    }
}
