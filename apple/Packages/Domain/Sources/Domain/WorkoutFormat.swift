/// Formats de séance gérés par le moteur (EMOM est nouveau par rapport à l'app Expo).
public enum WorkoutFormat: String, Sendable, Codable, Equatable, CaseIterable {
    case forTime
    case amrap
    case emom
    case intervals
}
