import SwiftUI
import CryptoKit

struct DurationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var wavePoints: [CGPoint] = []
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Single waveform that changes color based on progress
                    WaveformView(points: wavePoints)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: appState.currentTheme.foreground.primary, location: 0),
                                    .init(color: appState.currentTheme.foreground.primary, location: progress),
                                    .init(color: appState.currentTheme.foreground.tertiary, location: progress),
                                    .init(color: appState.currentTheme.foreground.tertiary, location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 24)
                }
            }
            .frame(height: 24)
            .onChange(of: appState.currentTrack) { _, track in
                if let duration = track?.durationSeconds {
                    generateWaveform(width: 100, duration: duration)
                } else {
                    // Generate placeholder waveform when no track is loaded
                    generateWaveform(width: 100, duration: 180) // Default 3 minutes
                }
            }
            .onAppear {
                if let duration = appState.currentTrack?.durationSeconds {
                    generateWaveform(width: 100, duration: duration)
                } else {
                    // Generate placeholder waveform when no track is loaded
                    generateWaveform(width: 100, duration: 180) // Default 3 minutes
                }
            }
            
            // Time labels
            HStack {
                Text(formatDuration(Double(appState.currentPlaybackSeconds)))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                    .font(.caption.monospaced())
                
                Spacer()
                
                Text(formatDuration(Double(appState.currentTrack?.durationSeconds ?? 0)))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                    .font(.caption.monospaced())
            }
        }
    }
    
    private var progress: Double {
        guard let duration = appState.currentTrack?.durationSeconds,
              duration > 0 else { return 0 }
        return Double(appState.currentPlaybackSeconds) / Double(duration)
    }
    
    private func generateWaveform(width: Int, duration: Int) {
        // Create a hash from the duration
        let durationString = String(duration)
        let titleData = Data(durationString.utf8)
        let hash = SHA256.hash(data: titleData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Use the hash to seed our random number generator
        var generator = SeededRandomNumberGenerator(seed: UInt64(hashString.prefix(16), radix: 16) ?? 0)
        
        // Generate points with some randomness but ensure they connect smoothly
        var points: [CGPoint] = []
        let segments = width
        let segmentWidth = 1.0
        var lastY = Double.random(in: 0.3...0.7, using: &generator)
        
        points.append(CGPoint(x: 0, y: lastY))
        
        for i in 1...segments {
            let x = Double(i) * segmentWidth
            
            // Generate a new y value that's not too far from the last one
            let maxChange = 0.2
            let change = Double.random(in: -maxChange...maxChange, using: &generator)
            var newY = lastY + change
            
            // Keep y values within bounds
            newY = max(0.2, min(0.8, newY))
            lastY = newY
            
            points.append(CGPoint(x: x, y: newY))
        }
        
        // Normalize x coordinates to 0-1 range
        let normalizedPoints = points.map { point in
            CGPoint(x: point.x / Double(segments), y: point.y)
        }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            wavePoints = normalizedPoints
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Random number generator with seed
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private let multiplier: UInt64 = 6364136223846793005
    private let increment: UInt64 = 1442695040888963407
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* multiplier &+ increment
        return state
    }
}

#Preview {
    let previewState = AppState()
    return DurationView()
        .environmentObject(previewState)
        .frame(maxWidth: 400)
        .padding()
        .background(previewState.currentTheme.background.primary)
} 