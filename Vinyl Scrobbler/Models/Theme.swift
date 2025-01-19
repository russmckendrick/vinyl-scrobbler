import SwiftUI

/// Represents a complete theme configuration
struct Theme: Codable {
    let version: String
    let themes: ThemeSet
    
    struct ThemeSet: Codable {
        let light: ThemeColors
        let dark: ThemeColors
    }
    
    struct ThemeColors: Codable {
        let background: BackgroundColors
        let foreground: ForegroundColors
        let accent: AccentColors
        let border: BorderColors
        let artwork: ArtworkColors
        let input: InputColors
        let status: StatusColors
    }
    
    struct BackgroundColors: Codable {
        let primary: Color
        let secondary: Color
        let tertiary: Color
        let overlay: Color
    }
    
    struct ForegroundColors: Codable {
        let primary: Color
        let secondary: Color
        let tertiary: Color
    }
    
    struct AccentColors: Codable {
        let primary: Color
        let secondary: Color
    }
    
    struct BorderColors: Codable {
        let primary: Color
        let secondary: Color
    }
    
    struct ArtworkColors: Codable {
        let placeholder: Color
        let shadow: Color
        let overlay: ArtworkOverlay
        
        struct ArtworkOverlay: Codable {
            let gradient: [Color]
        }
    }
    
    struct InputColors: Codable {
        let background: Color
        let text: Color
        let placeholder: Color
    }
    
    struct StatusColors: Codable {
        let success: Color
        let warning: Color
        let error: Color
    }
}

// MARK: - Color Coding
extension Color: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        self = Color(hex: string)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
    
    // Initialize color from hex string or rgba string
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
    
    // Initialize color from rgba string
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
    
    // Convert color to hex string
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
    static var preview: Theme {
        guard let url = Bundle.main.url(forResource: "ColorTheme", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let theme = try? JSONDecoder().decode(Theme.self, from: data) else {
            fatalError("Failed to load preview theme")
        }
        return theme
    }
} 