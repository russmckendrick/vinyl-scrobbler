import SwiftUI

struct DynamicPlaceholderView: View {
    @EnvironmentObject private var appState: AppState
    @State private var gradientColors: [Color] = []
    @State private var previousColors: [Color] = []
    
    // Curated colors from the app icon
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
                // Dynamic gradient background
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Gradient overlay for player transition
                LinearGradient(
                    colors: appState.currentTheme.artwork.overlay.gradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Text overlay
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
            // Initialize with first colors
            updateColors()
            previousColors = gradientColors
            
            // Start timer to update colors very slowly
            Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                let nextColors = generateNextColors()
                withAnimation(.easeInOut(duration: 8)) {
                    gradientColors = nextColors
                }
                previousColors = gradientColors
            }
        }
    }
    
    private func generateNextColors() -> [Color] {
        let now = Date()
        let nanoseconds = Int(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1_000_000_000)
        
        // Use time to create a deterministic but seemingly random selection
        var generator = SeededRandomNumberGenerator(seed: UInt64(nanoseconds))
        
        // Select 3 different colors from our curated set
        var selectedIndices = Set<Int>()
        while selectedIndices.count < 3 {
            let index = Int.random(in: 0..<DynamicPlaceholderView.curatedColors.count, using: &generator)
            selectedIndices.insert(index)
        }
        
        // Convert to array and map to colors
        return selectedIndices.map { DynamicPlaceholderView.curatedColors[$0] }
    }
    
    private func updateColors() {
        gradientColors = generateNextColors()
    }
    
    // Helper function to generate placeholder waveform points
    static func generatePlaceholderWaveform(width: Int, timeInterval: TimeInterval) -> [CGPoint] {
        var points: [CGPoint] = []
        let segments = width
        
        // Use more precise time components for the seed
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 1000)
        let seed = UInt64(timeInterval) * 1000 + UInt64(milliseconds)
        var generator = SeededRandomNumberGenerator(seed: seed)
        
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

#Preview {
    let previewState = AppState()
    return DynamicPlaceholderView()
        .environmentObject(previewState)
        .frame(width: 400, height: 400)
        .background(previewState.currentTheme.background.primary)
} 