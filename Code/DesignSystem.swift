import SwiftUI

/// The centralized design system enforcing BC2's high-density layout 
/// wrapped entirely in iOS-native aesthetics.
public struct DesignSystem {
    
    // MARK: - Spacing & Grid (The BC2 Density)
    public struct Layout {
        /// Extremely tight padding for multi-day views and event pills
        public static let microPadding: CGFloat = 2.0
        /// Standard internal padding for list items and dense forms
        public static let densePadding: CGFloat = 4.0
        /// Edge-to-edge screen margins (smaller than Apple's default 16pt)
        public static let screenEdge: CGFloat = 8.0
        
        /// Standardized height for the day/week timeline cells
        public static let timelineHourHeight: CGFloat = 45.0
    }
    
    // MARK: - iOS Native Typography (San Francisco)
    public struct Typography {
        /// Text wrapping inside the dense month/week pills
        public static let eventPill = Font.system(size: 10, weight: .medium, design: .default)
        /// Standard body text for forms and settings
        public static let body = Font.system(size: 14, weight: .regular, design: .default)
        /// Bold headers for day/month dividers
        public static let header = Font.system(size: 16, weight: .semibold, design: .default)
        /// Tiny, highly legible font for timestamps
        public static let timeLabel = Font.system(size: 9, weight: .semibold, design: .default)
    }
    
    // MARK: - iOS Aesthetics & Materials
    public struct Aesthetics {
        /// Standard iOS corner radius mimicking native widgets and popovers
        public static let cornerRadius: CGFloat = 10.0
        /// Tighter radius specifically for the dense event pills
        public static let pillRadius: CGFloat = 4.0
        
        /// iOS native material for the floating bottom toolbars (like the 1-14 day slider)
        public static let toolbarMaterial: Material = .ultraThinMaterial
        
        /// Subtle, native divider lines for the rigid grid structure
        public static let gridLine = Color(uiColor: .separator).opacity(0.4)
    }
    
    // MARK: - SFSymbol Iconography Reference
    public struct Icons {
        public static let eventMenu = "ellipsis.circle.fill"
        public static let dragHandle = "line.3.horizontal"
        public static let taskCheck = "checkmark.circle"
        public static let location = "mappin.and.ellipse"
        public static let sliderSettings = "slider.horizontal.3"
    }
}