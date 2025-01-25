/// DurationView: A SwiftUI view that displays track duration information with a dynamic
/// waveform visualization. The waveform is generated deterministically based on track
/// duration and updates its appearance based on playback progress.
import SwiftUI
import CryptoKit

/// A view that shows playback progress with a waveform visualization and time labels
struct DurationView: View {
    /// Access to the global app state for track and theme information
    @EnvironmentObject private var appState: AppState
    /// Array of points defining the waveform shape
    @State private var wavePoints: [CGPoint] = []
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar with waveform visualization
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Waveform with gradient color based on playback progress
                    WaveformView(points: wavePoints)
                        .fill(
                            LinearGradient(
                                stops: [
                                    // Primary color for played portion
                                    .init(color: appState.currentTheme.foreground.primary, location: 0),
                                    .init(color: appState.currentTheme.foreground.primary, location: progress),
                                    // Secondary color for remaining portion
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
            // Generate new waveform when track changes
            .onChange(of: appState.currentTrack) { _, track in
                if let duration = track?.durationSeconds {
                    generateWaveform(width: 100, duration: duration)
                } else {
                    // Default waveform for no track
                    generateWaveform(width: 100, duration: 180) // Default 3 minutes
                }
            }
            // Initial waveform generation
            .onAppear {
                if let duration = appState.currentTrack?.durationSeconds {
                    generateWaveform(width: 100, duration: duration)
                } else {
                    // Default waveform for no track
                    generateWaveform(width: 100, duration: 180) // Default 3 minutes
                }
            }
            
            // Time display showing current position and total duration
            HStack {
                // Current playback position
                Text(formatDuration(Double(appState.currentPlaybackSeconds)))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                    .font(.caption.monospaced())
                
                Spacer()
                
                // Total track duration
                Text(formatDuration(Double(appState.currentTrack?.durationSeconds ?? 0)))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                    .font(.caption.monospaced())
            }
        }
    }
    
    /// Calculates the current playback progress as a ratio (0-1)
    private var progress: Double {
        guard let duration = appState.currentTrack?.durationSeconds,
              duration > 0 else { return 0 }
        return Double(appState.currentPlaybackSeconds) / Double(duration)
    }
    
    /// Generates a deterministic waveform pattern based on track duration
    /// - Parameters:
    ///   - width: Number of segments in the waveform
    ///   - duration: Track duration in seconds used to seed the pattern
    private func generateWaveform(width: Int, duration: Int) {
        // Create a deterministic hash from the duration
        let durationString = String(duration)
        let titleData = Data(durationString.utf8)
        let hash = SHA256.hash(data: titleData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Seed random generator with hash for consistent results
        var generator = SeededRandomNumberGenerator(seed: UInt64(hashString.prefix(16), radix: 16) ?? 0)
        
        // Generate smooth, connected waveform points
        var points: [CGPoint] = []
        let segments = width
        let segmentWidth = 1.0
        var lastY = Double.random(in: 0.3...0.7, using: &generator)
        
        points.append(CGPoint(x: 0, y: lastY))
        
        for i in 1...segments {
            let x = Double(i) * segmentWidth
            
            // Ensure smooth transitions between points
            let maxChange = 0.2
            let change = Double.random(in: -maxChange...maxChange, using: &generator)
            var newY = lastY + change
            
            // Constrain amplitude within reasonable bounds
            newY = max(0.2, min(0.8, newY))
            lastY = newY
            
            points.append(CGPoint(x: x, y: newY))
        }
        
        // Normalize x coordinates to unit scale
        let normalizedPoints = points.map { point in
            CGPoint(x: point.x / Double(segments), y: point.y)
        }
        
        // Animate waveform updates
        withAnimation(.easeInOut(duration: 0.5)) {
            wavePoints = normalizedPoints
        }
    }
    
    /// Formats a duration in seconds to a "M:SS" string format
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted duration string
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

/// A deterministic random number generator that produces consistent
/// sequences based on an initial seed value
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    /// Linear congruential generator multiplier
    private let multiplier: UInt64 = 6364136223846793005
    /// Linear congruential generator increment
    private let increment: UInt64 = 1442695040888963407
    /// Current generator state
    private var state: UInt64
    
    /// Creates a new generator with the specified seed
    /// - Parameter seed: Initial seed value
    init(seed: UInt64) {
        state = seed
    }
    
    /// Generates the next random value in the sequence
    mutating func next() -> UInt64 {
        state = state &* multiplier &+ increment
        return state
    }
}

/// Preview provider for DurationView
#Preview {
    let previewState = AppState()
    return DurationView()
        .environmentObject(previewState)
        .frame(maxWidth: 400)
        .padding()
        .background(previewState.currentTheme.background.primary)
}