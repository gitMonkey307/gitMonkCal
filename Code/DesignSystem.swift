import SwiftUI

public struct DesignSystem {
    public struct Layout {
        public static let microPadding: CGFloat = 2.0
        public static let densePadding: CGFloat = 4.0
        public static let screenEdge: CGFloat = 8.0
        public static let timelineHourHeight: CGFloat = 45.0
    }
    
    public struct Typography {
        public static let eventPill = Font.system(size: 10, weight: .medium, design: .default)
        public static let body = Font.system(size: 14, weight: .regular, design: .default)
        public static let header = Font.system(size: 16, weight: .semibold, design: .default)
        public static let timeLabel = Font.system(size: 9, weight: .semibold, design: .default)
    }
    
    public struct Aesthetics {
        public static let cornerRadius: CGFloat = 10.0
        public static let pillRadius: CGFloat = 4.0
        public static let toolbarMaterial: Material = .ultraThinMaterial
        public static let gridLine = Color(uiColor: .separator).opacity(0.4)
    }
    
    public struct Icons {
        public static let eventMenu = "ellipsis.circle.fill"
        public static let dragHandle = "line.3.horizontal"
        public static let taskCheck = "checkmark.circle"
        public static let location = "mappin.and.ellipse"
        public static let sliderSettings = "slider.horizontal.3"
    }
}
