import SwiftUI

public extension Color {
    /// Couleur à partir d'un hexadécimal 0xRRGGBB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Tokens relevés dans le fichier Figma « Another Intrval App » (écrans Run).
public enum DS {
    public enum Colors {
        public static let textPrimary = Color(hex: 0x2A1A24)
        public static let textSecondary = Color(red: 80 / 255, green: 40 / 255, blue: 60 / 255, opacity: 0.5)
        public static let textTertiary = Color(red: 80 / 255, green: 40 / 255, blue: 60 / 255, opacity: 0.4)
        public static let textFaint = Color(red: 80 / 255, green: 40 / 255, blue: 60 / 255, opacity: 0.22)
        public static let glass = Color.white.opacity(0.35)
        public static let glassSoft = Color.white.opacity(0.25)
        public static let glassBorder = Color.white.opacity(0.6)
        public static let accentPurple = Color(hex: 0x7050A0)
        public static let accentGreen = Color(hex: 0x5A9E57)
        public static let accentError = Color(hex: 0xE05555)
        /// Fond du mode gym.
        public static let gymBackground = Color(hex: 0xAAEE66)

        public static let backgroundGradient = LinearGradient(
            stops: [
                .init(color: Color(hex: 0xF0C4A0), location: 0),
                .init(color: Color(hex: 0xE8B8C8), location: 0.33),
                .init(color: Color(hex: 0xD4B8E0), location: 0.66),
                .init(color: Color(hex: 0xC8C0E8), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public enum Radius {
        public static let chip: CGFloat = 20
        public static let badge: CGFloat = 12
        public static let small: CGFloat = 14
        public static let medium: CGFloat = 18
    }
}
