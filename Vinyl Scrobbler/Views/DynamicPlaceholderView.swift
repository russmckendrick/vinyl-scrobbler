/// DynamicPlaceholderView: A SwiftUI view that provides an animated placeholder
/// when no album artwork is available. It creates a smooth, animated gradient background
/// using curated colors from the app's design palette and displays placeholder text.
import SwiftUI

/// A view that displays an animated gradient placeholder with text overlay
struct DynamicPlaceholderView: View {
    /// Access to the global app state for theming
    @EnvironmentObject private var appState: AppState
    /// Current colors used in the gradient animation
    @State private var gradientColors: [Color] = []
    /// Previous colors used for smooth transitions
    @State private var previousColors: [Color] = []
    
    /// Carefully selected colors that complement the app's design
    /// Colors are chosen to create warm, engaging gradients that match the app icon's palette
    private static let curatedColors: [Color] = [
        Color(red: 0.95, green: 0.4, blue: 0.3),   // Warm Red
        Color(red: 1.0, green: 0.5, blue: 0.2),    // Orange
        Color(red: 1.0, green: 0.65, blue: 0.3),   // Light Orange
        Color(red: 0.95, green: 0.75, blue: 0.4),  // Peach
        Color(red: 0.98, green: 0.45, blue: 0.25), // Bright Orange
        Color(red: 0.92, green: 0.35, blue: 0.2),  // Deep Orange
        Color(red: 0.85, green: 0.3, blue: 0.2),   // Burnt Orange
        Color(red: 0.8, green: 0.3, blue: 0.4),    // Dark Pink
        Color(red: 0.9, green: 0.4, blue: 0.5),    // Medium Pink
        Color(red: 0.7, green: 0.25, blue: 0.3),   // Deep Red
        Color(red: 0.6, green: 0.2, blue: 0.25),   // Burgundy
        Color(red: 0.85, green: 0.35, blue: 0.25)  // Coral Red
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background gradient using selected colors
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Theme-aware overlay gradient for visual consistency
                LinearGradient(
                    colors: appState.currentTheme.artwork.overlay.gradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Placeholder text with responsive sizing
                VStack(spacing: 8) {
                    Text("No Album")
                        .font(.system(size: geometry.size.width * 0.12, weight: .bold))
                        .foregroundStyle(appState.currentTheme.foreground.primary.opacity(0.1))
                    Text("Loaded")
                        .font(.system(size: geometry.size.width * 0.12, weight: .bold))
                        .foregroundStyle(appState.currentTheme.foreground.primary.opacity(0.1))
                    Text("•••")
                        .font(.system(size: geometry.size.width * 0.12, weight: .bold))
                        .foregroundStyle(appState.currentTheme.foreground.primary.opacity(0.05))
                }
                .multilineTextAlignment(.center)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .onAppear {
            // Initialize the gradient colors
            updateColors()
            previousColors = gradientColors
            
            // Set up periodic color transitions
            Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                let nextColors = generateNextColors()
                withAnimation(.easeInOut(duration: 8)) {
                    gradientColors = nextColors
                }
                previousColors = gradientColors
            }
        }
    }
    
    /// Generates the next set of colors for the gradient animation
    /// Uses current time to create a deterministic but varied selection
    /// - Returns: Array of three colors selected from the curated palette
    private func generateNextColors() -> [Color] {
        let now = Date()
        let nanoseconds = Int(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1_000_000_000)
        
        // Create deterministic selection based on current time
        var generator = SeededRandomNumberGenerator(seed: UInt64(nanoseconds))
        
        // Select three unique colors from the palette
        var selectedIndices = Set<Int>()
        while selectedIndices.count < 3 {
            let index = Int.random(in: 0..<DynamicPlaceholderView.curatedColors.count, using: &generator)
            selectedIndices.insert(index)
        }
        
        // Map indices to actual colors
        return selectedIndices.map { DynamicPlaceholderView.curatedColors[$0] }
    }
    
    /// Updates the current gradient colors with a new selection
    private func updateColors() {
        gradientColors = generateNextColors()
    }
    
    /// Generates a deterministic waveform pattern for placeholder states
    /// - Parameters:
    ///   - width: Number of segments in the waveform
    ///   - timeInterval: Time value used to seed the pattern generation
    /// - Returns: Array of points defining the waveform shape
    static func generatePlaceholderWaveform(width: Int, timeInterval: TimeInterval) -> [CGPoint] {
        var points: [CGPoint] = []
        let segments = width
        
        // Create precise time-based seed
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 1000)
        let seed = UInt64(timeInterval) * 1000 + UInt64(milliseconds)
        var generator = SeededRandomNumberGenerator(seed: seed)
        
        // Generate smooth, connected points
        var lastY = Double.random(in: 0.3...0.7, using: &generator)
        points.append(CGPoint(x: 0, y: lastY))
        
        for i in 1...segments {
            let x = Double(i)
            let maxChange = 0.2
            let change = Double.random(in: -maxChange...maxChange, using: &generator)
            var newY = lastY + change
            newY = max(0.2, min(0.8, newY))
            lastY = newY
            
            points.append(CGPoint(x: x / Double(segments), y: newY))
        }
        
        return points
    }
}

/// Preview provider for DynamicPlaceholderView
#Preview {
    let previewState = AppState()
    return DynamicPlaceholderView()
        .environmentObject(previewState)
        .frame(width: 400, height: 400)
        .background(previewState.currentTheme.background.primary)
}