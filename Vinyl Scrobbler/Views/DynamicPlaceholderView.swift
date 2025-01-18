import SwiftUI

struct DynamicPlaceholderView: View {
    @State private var gradientColors: [Color] = []
    @State private var previousColors: [Color] = []
    
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
                    colors: [
                        .clear,
                        .clear,
                        .clear,
                        .black.opacity(0.3),
                        .black.opacity(0.6),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Vinyl icon overlay
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: geometry.size.width * 0.3))
                    .foregroundStyle(.white.opacity(0.15))
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
        let calendar = Calendar.current
        let nanoseconds = Int(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1_000_000_000)
        
        // Get all time components
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)
        let millisecond = nanoseconds / 1_000_000
        
        // Create a hash from all time components
        let timeString = String(format: "%02d%02d%02d%03d", hour, minute, second, millisecond)
        let hash = timeString.hash
        
        // Use the hash to generate base hues with smaller variations from previous colors
        let baseHue = abs(Double(hash % 1000) / 1000.0)
        let offsetHue1 = abs(Double((hash >> 10) % 1000) / 1000.0)
        let offsetHue2 = abs(Double((hash >> 20) % 1000) / 1000.0)
        
        // Create new colors with subtle variations
        return [
            Color(hue: baseHue, 
                  saturation: 0.7 + (Double(millisecond) / 10000.0), 
                  brightness: 0.8),
            Color(hue: offsetHue1, 
                  saturation: 0.6 + (Double(second) / 240.0), 
                  brightness: 0.7),
            Color(hue: offsetHue2, 
                  saturation: 0.7, 
                  brightness: 0.6 + (Double(minute) / 240.0))
        ]
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
    DynamicPlaceholderView()
        .frame(width: 400, height: 400)
        .background(.black)
} 