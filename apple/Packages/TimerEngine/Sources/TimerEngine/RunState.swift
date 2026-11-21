import Foundation

/// Instantané de l'exécution à un instant donné.
public struct RunState: Sendable, Equatable {
    public var phase: RunPhase
    /// Temps écoulé de la partie chronométrée (hors compte à rebours).
    public var elapsed: TimeInterval
    public var countdownRemaining: TimeInterval
    /// Tour en cours (0 = premier).
    public var roundIndex: Int
    /// Bloc en cours dans le tour (0 = premier). Toujours 0 pour For Time / AMRAP.
    public var blockIndex: Int
    public var blockElapsed: TimeInterval?
    public var blockRemaining: TimeInterval?
    /// Temps restant avant la fin (cap, durée AMRAP, ou fin du dernier bloc). `nil` = pas de limite.
    public var totalRemaining: TimeInterval?
    public var roundsCompleted: Int
    /// Vrai pour les formats découpés en blocs (EMOM, fractionné).
    public var isBlockBased: Bool

    public static let idle = RunState(
        phase: .idle, elapsed: 0, countdownRemaining: 0,
        roundIndex: 0, blockIndex: 0, blockElapsed: nil, blockRemaining: nil,
        totalRemaining: nil, roundsCompleted: 0, isBlockBased: false
    )
}
