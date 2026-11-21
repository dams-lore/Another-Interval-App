import Domain

/// Enregistre les signaux reçus (tests sans son ni vibration).
@MainActor
public final class RecordingGuidanceOutput: GuidanceOutput {
    public private(set) var cues: [GuidanceCue] = []

    public init() {}

    public func play(_ cue: GuidanceCue) {
        cues.append(cue)
    }
}
