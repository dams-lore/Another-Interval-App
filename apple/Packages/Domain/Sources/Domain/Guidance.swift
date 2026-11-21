/// Signaux sonores / haptiques émis pendant une séance.
public enum GuidanceCue: Sendable, Equatable {
    /// Compte à rebours 3-2-1.
    case countdownTick(Int)
    /// Départ du chrono.
    case go
    /// Il reste 10 secondes (bloc, cap ou durée AMRAP).
    case tenSecondsWarning
    /// Fin d'un bloc (ou bloc passé avec Skip).
    case blockEnd
    /// Fin de séance.
    case sessionEnd
}

/// Sortie audio / haptique. Implémentée par Platform (iPhone), par un faux dans les tests.
@MainActor
public protocol GuidanceOutput {
    func play(_ cue: GuidanceCue)
}
