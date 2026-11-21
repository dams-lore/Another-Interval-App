import Foundation

public enum StepType: String, Sendable, Codable, Equatable, CaseIterable {
    case reps
    case distance
    case time
}

/// Un bloc de séance. Pour `type == .time`, `value` est en secondes.
public struct Step: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var type: StepType
    public var movement: String
    public var value: Double
    public var unit: String?
    public var weight: Double?
    public var height: Double?
    public var targetPace: Double?
    public var targetHR: Int?
    public var notes: String?

    public init(
        id: UUID = UUID(),
        type: StepType,
        movement: String,
        value: Double,
        unit: String? = nil,
        weight: Double? = nil,
        height: Double? = nil,
        targetPace: Double? = nil,
        targetHR: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.type = type
        self.movement = movement
        self.value = value
        self.unit = unit
        self.weight = weight
        self.height = height
        self.targetPace = targetPace
        self.targetHR = targetHR
        self.notes = notes
    }
}
