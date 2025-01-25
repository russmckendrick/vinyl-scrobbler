import SwiftUI

/// Represents a complete theme configuration for the application
/// Provides a comprehensive color scheme system supporting both light and dark modes
/// The theme is loaded from a JSON file and includes various color categories for different UI elements
struct Theme: Codable {
    /// Version identifier for the theme configuration
    let version: String
    /// Container for both light and dark theme variants
    let themes: ThemeSet
    
    /// Contains separate color schemes for light and dark modes
    struct ThemeSet: Codable {
        /// Color scheme for light mode
        let light: ThemeColors
        /// Color scheme for dark mode
        let dark: ThemeColors
    }
    
    /// Comprehensive collection of color categories for different UI elements
    struct ThemeColors: Codable {
        /// Colors for different background layers
        let background: BackgroundColors
        /// Text and icon colors
        let foreground: ForegroundColors
        /// Accent colors for highlighting and emphasis
        let accent: AccentColors
        /// Colors for UI borders and dividers
        let border: BorderColors
        /// Colors specific to album artwork display
        let artwork: ArtworkColors
        /// Colors for input fields and controls
        let input: InputColors
        /// Colors for different status indicators
        let status: StatusColors
    }
    
    /// Colors for different background layers in the UI
    struct BackgroundColors: Codable {
        /// Main background color
        let primary: Color
        /// Background color for secondary elements
        let secondary: Color
        /// Background color for tertiary elements
        let tertiary: Color
        /// Semi-transparent overlay background
        let overlay: Color
    }
    
    /// Colors for text and icons
    struct ForegroundColors: Codable {
        /// Main text color
        let primary: Color
        /// Secondary text color for less emphasis
        let secondary: Color
        /// Tertiary text color for least emphasis
        let tertiary: Color
    }
    
    /// Accent colors for highlighting and emphasis
    struct AccentColors: Codable {
        /// Primary accent color for main highlights
        let primary: Color
        /// Secondary accent color for subtle emphasis
        let secondary: Color
    }
    
    /// Colors for UI borders and dividers
    struct BorderColors: Codable {
        /// Main border color
        let primary: Color
        /// Secondary border color for subtle divisions
        let secondary: Color
    }
    
    /// Colors specific to album artwork display
    struct ArtworkColors: Codable {
        /// Color shown when artwork is loading
        let placeholder: Color
        /// Shadow color for artwork elements
        let shadow: Color
        /// Gradient overlay for artwork
        let overlay: ArtworkOverlay
        
        /// Defines gradient colors for artwork overlay
        struct ArtworkOverlay: Codable {
            /// Array of colors forming the gradient
            let gradient: [Color]
        }
    }
    
    /// Colors for input fields and controls
    struct InputColors: Codable {
        /// Background color for input fields
        let background: Color
        /// Text color for input fields
        let text: Color
        /// Placeholder text color
        let placeholder: Color
    }
    
    /// Colors for different status indicators
    struct StatusColors: Codable {
        /// Color for success states
        let success: Color
        /// Color for warning states
        let warning: Color
        /// Color for error states
        let error: Color
    }
}

// MARK: - Color Coding
/// Extension to make SwiftUI Color conform to Codable protocol
extension Color: Codable {
    /// Decodes a color from a hex or rgba string
    /// - Parameter decoder: The decoder to read from
    /// - Throws: DecodingError if the color string is invalid
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        self = Color(hex: string)
    }
    
    /// Encodes the color as a hex string
    /// - Parameter encoder: The encoder to write to
    /// - Throws: EncodingError if the color cannot be encoded
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
    
    /// Initializes a Color from a hex string or rgba string
    /// - Parameter hex: The color string in hex format (#RRGGBB) or rgba format
    init(hex: String) {
        if hex.lowercased().hasPrefix("rgba") {
            self = Color(rgbaString: hex)
            return
        }
        
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    /// Initializes a Color from an rgba string
    /// - Parameter rgbaString: The color string in rgba format (rgba(r,g,b,a))
    init(rgbaString: String) {
        let components = rgbaString
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        let r = Double(components[0])! / 255.0
        let g = Double(components[1])! / 255.0
        let b = Double(components[2])! / 255.0
        let a = Double(components[3])!
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Converts the color to a hex string
    /// - Returns: A string representation of the color in hex format (#RRGGBB)
    var hexString: String {
        guard let components = NSColor(self).cgColor.components else { return "#000000" }
        
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Preview Helper
extension Theme {
    /// Provides a preview theme for SwiftUI previews
    /// Loads the theme from the bundled ColorTheme.json file
    /// - Returns: A Theme instance for preview purposes
    /// - Fatal Error: If the theme file cannot be loaded or decoded
    static var preview: Theme {
        guard let url = Bundle.main.url(forResource: "ColorTheme", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let theme = try? JSONDecoder().decode(Theme.self, from: data) else {
            fatalError("Failed to load preview theme")
        }
        return theme
    }
}