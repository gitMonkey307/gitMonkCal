import SwiftUI

public enum DesignSystem {
    public enum Typography {
        public static let monthDayNumber = Font.system(size: 10, weight: .bold, design: .rounded)
        public static let eventPill = Font.system(size: 8, weight: .semibold)
        public static let timeLabel = Font.system(size: 7, weight: .regular)
        public static let sidebarItem = Font.system(size: 14, weight: .medium)
    }
    public enum Layout {
        public static let eventPillHeight: CGFloat = 11
        public static let cellPadding: CGFloat = 0.5
        public static let cornerRadius: CGFloat = 1
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") { hexSanitized.remove(at: hexSanitized.startIndex) }
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        self.init(red: Double((rgb & 0xFF0000) >> 16) / 255.0, green: Double((rgb & 0x00FF00) >> 8) / 255.0, blue: Double(rgb & 0x0000FF) / 255.0)
    }
}
