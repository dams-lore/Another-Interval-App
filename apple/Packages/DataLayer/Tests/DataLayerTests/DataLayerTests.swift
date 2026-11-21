import Testing
import DataLayer

@Suite struct DataLayerTests {
    @Test func moduleNameIsStable() {
        #expect(DataLayer.moduleName == "DataLayer")
    }
}
