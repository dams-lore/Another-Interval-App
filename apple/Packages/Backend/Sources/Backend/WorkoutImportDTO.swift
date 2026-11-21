import Foundation

/// Réponse JSON de l'IA pour une séance (même structure que l'app Expo).
public struct WorkoutImportDTO: Codable, Sendable, Equatable {
    public struct StepDTO: Codable, Sendable, Equatable {
        public var type: String
        public var movement: String
        public var value: Double
        public var unit: String?
        public var weight: Double?
        public var notes: String?

        public init(type: String, movement: String, value: Double, unit: String? = nil, weight: Double? = nil, notes: String? = nil) {
            self.type = type
            self.movement = movement
            self.value = value
            self.unit = unit
            self.weight = weight
            self.notes = notes
        }
    }

    public var name: String?
    public var format: String
    public var capTime: Double?
    public var rounds: Double?
    public var steps: [StepDTO]

    enum CodingKeys: String, CodingKey {
        case name, format, rounds, steps
        case capTime = "cap_time"
    }

    public init(name: String? = nil, format: String, capTime: Double? = nil, rounds: Double? = nil, steps: [StepDTO]) {
        self.name = name
        self.format = format
        self.capTime = capTime
        self.rounds = rounds
        self.steps = steps
    }
}
