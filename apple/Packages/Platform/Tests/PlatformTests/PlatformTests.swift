import Foundation
import Testing
import Platform

@Suite struct PlatformTests {
    @Test func moduleNameIsStable() {
        #expect(Platform.moduleName == "Platform")
    }
}

@Suite struct SineWAVTests {
    @Test func headerAndSizeAreCorrect() {
        let data = SineWAV.data(frequency: 880, durationMs: 100)
        let samples = SineWAV.sampleRate * 100 / 1000
        #expect(data.count == 44 + samples * 2)
        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "RIFF")
        #expect(String(decoding: data[8..<12], as: UTF8.self) == "WAVE")
    }

    @Test func longerBeepIsLonger() {
        let short = SineWAV.data(frequency: 880, durationMs: 180)
        let long = SineWAV.data(frequency: 880, durationMs: 540)
        #expect(long.count > short.count)
    }
}
