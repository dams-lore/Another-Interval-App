import Foundation

/// Formatage des chronos (pur, testé).
public enum RunFormat {
    /// Temps écoulé : arrondi à la seconde inférieure (« 01:22 »).
    public static func elapsed(_ seconds: TimeInterval) -> String {
        format(Int(max(0, seconds).rounded(.down)))
    }

    /// Temps restant : arrondi à la seconde supérieure, pour ne jamais afficher 00:00 avant la fin.
    public static func remaining(_ seconds: TimeInterval) -> String {
        format(Int(max(0, seconds).rounded(.up)))
    }

    private static func format(_ total: Int) -> String {
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
