import Foundation
import Domain
import Backend

/// DTO de l'IA → entité `Workout` (le schéma externe ne fuit jamais hors de Backend / DataLayer).
public enum WorkoutImportMapper {
    public static func workout(from dto: WorkoutImportDTO, defaultName: String, now: Date) throws -> Workout {
        let format: WorkoutFormat
        switch dto.format {
        case "for_time": format = .forTime
        case "amrap": format = .amrap
        case "intervals": format = .intervals
        case "emom": format = .emom
        default: throw DomainError.validation("Format de séance inconnu : « \(dto.format) ».")
        }

        let steps = try dto.steps.map { step -> Step in
            guard let type = StepType(rawValue: step.type) else {
                throw DomainError.validation("Type de bloc inconnu : « \(step.type) ».")
            }
            var value = step.value
            var unit = step.unit
            // Les blocs chronométrés sont stockés en secondes dans le Domain.
            if type == .time, unit == "min" {
                value *= 60
                unit = "s"
            }
            return Step(type: type, movement: step.movement, value: value, unit: unit, weight: step.weight, notes: step.notes)
        }

        let trimmedName = dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let capTime = dto.capTime.flatMap { $0 > 0 ? $0 : nil }
        let intervalSeconds = dto.intervalSeconds.flatMap { $0 > 0 ? $0 : nil }
        let rounds = dto.rounds.map { Int($0.rounded()) }.flatMap { $0 > 0 ? $0 : nil }

        return Workout(
            name: trimmedName.isEmpty ? defaultName : trimmedName,
            format: format,
            steps: steps,
            capTime: capTime,
            rounds: rounds,
            intervalSeconds: intervalSeconds,
            source: .photoImport,
            createdAt: now,
            updatedAt: now
        )
    }
}
