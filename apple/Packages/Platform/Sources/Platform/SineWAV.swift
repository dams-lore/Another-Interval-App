import Foundation

/// Génère un bip (WAV PCM 16 bits mono) : pas de fichier son à embarquer.
public enum SineWAV {
    public static let sampleRate = 44_100

    public static func data(frequency: Double, durationMs: Int, amplitude: Double = 0.8) -> Data {
        let sampleCount = sampleRate * durationMs / 1000
        let fade = min(sampleCount / 2, sampleRate / 200)  // 5 ms : évite le « clic »
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)
        for index in 0..<sampleCount {
            var envelope = 1.0
            if index < fade { envelope = Double(index) / Double(fade) }
            if index >= sampleCount - fade { envelope = Double(sampleCount - index) / Double(fade) }
            let value = sin(2 * .pi * frequency * Double(index) / Double(sampleRate)) * amplitude * envelope
            samples.append(Int16(max(-1, min(1, value)) * Double(Int16.max)))
        }

        let dataSize = sampleCount * 2
        var wav = Data()
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) } }
        wav.append(contentsOf: Array("RIFF".utf8)); append32(UInt32(36 + dataSize))
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8)); append32(16)
        append16(1); append16(1)                       // PCM, mono
        append32(UInt32(sampleRate)); append32(UInt32(sampleRate * 2))
        append16(2); append16(16)                      // alignement, bits par échantillon
        wav.append(contentsOf: Array("data".utf8)); append32(UInt32(dataSize))
        for sample in samples { append16(UInt16(bitPattern: sample)) }
        return wav
    }
}
