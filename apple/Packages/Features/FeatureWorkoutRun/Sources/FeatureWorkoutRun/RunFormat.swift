import Foundation
import Domain

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

    /// Format court « m:ss » (« 4:13 »), utilisé dans le parcours Every X.
    public static func short(_ seconds: TimeInterval, roundingUp: Bool = false) -> String {
        let total = Int(max(0, seconds).rounded(roundingUp ? .up : .down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func format(_ total: Int) -> String {
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

/// Texte d'une étape de séance (« 15 Burpees Over Row », « 20 cal Row », « 400 m Run »).
public enum StepFormat {
    public static func line(for step: Step) -> String {
        var amount = number(step.value)
        switch (step.type, step.unit) {
        case (.reps, nil), (.reps, "reps"): break
        case (.reps, let unit?): amount += " \(unit)"
        case (_, let unit?): amount += " \(unit)"
        case (_, nil): break
        }
        var text = "\(amount) \(step.movement)"
        if let weight = step.weight { text += " (\(number(weight)) kg)" }
        if let notes = step.notes, !notes.isEmpty { text += " — \(notes)" }
        return text
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
