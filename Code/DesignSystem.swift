import SwiftUI

public struct DesignSystem {
    public struct Layout {
        public static let microPadding: CGFloat = 2.0
        public static let densePadding: CGFloat = 4.0
        public static let defaultPadding: CGFloat = 8.0
        public static let screenEdge: CGFloat = 16.0
        public static let timelineHourHeight: CGFloat = 50.0
        public static let eventPillHeight: CGFloat = 14.0
    }
    
    public struct Typography {
        public static let monthDayNumber = Font.system(size: 11, weight: .semibold, design: .rounded)
        public static let eventPill = Font.system(size: 9, weight: .bold, design: .default)
        public static let body = Font.system(size: 15, weight: .regular, design: .default)
        public static let header = Font.system(size: 17, weight: .bold, design: .default)
        public static let timeLabel = Font.system(size: 10, weight: .medium, design: .monospaced)
        public static let sidebarItem = Font.system(size: 15, weight: .medium, design: .default)
    }
    
    public struct Aesthetics {
        public static let cornerRadius: CGFloat = 10.0
        public static let pillRadius: CGFloat = 4.0
        public static let toolbarMaterial: Material = .ultraThinMaterial
        public static let gridLine = Color(uiColor: .separator).opacity(0.3)
    }
    
    public struct Colors {
        public static let background = Color(uiColor: .systemBackground)
        public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
        public static let primaryText = Color(uiColor: .label)
        public static let secondaryText = Color(uiColor: .secondaryLabel)
        public static let defaultEvent = Color.blue
        public static let defaultTask = Color.green
    }
    
    public struct Icons {
        public static let eventMenu = "ellipsis.circle.fill"
        public static let dragHandle = "line.3.horizontal"
        public static let taskCheck = "checkmark.circle"
        public static let taskCompleted = "checkmark.circle.fill"
        public static let location = "mappin.and.ellipse"
        public static let sliderSettings = "slider.horizontal.3"
        public static let sidebarToggle = "sidebar.left"
        public static let add = "plus"
    }
}
