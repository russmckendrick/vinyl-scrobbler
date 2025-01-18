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
                    // Background track
                    WaveformView(points: wavePoints)
                        .fill(Color(nsColor: .tertiaryLabelColor))
                        .frame(height: 24)
                    
                    // Progress
                    WaveformView(points: wavePoints)
                        .fill(.white)
                        .frame(width: geometry.size.width * progress, height: 24)
                        .clipShape(Rectangle())
                }
            }
            .frame(height: 24)
            .onChange(of: appState.currentTrack?.title) { _, title in
                if let title = title {
                    generateWaveform(width: 100, title: title)
                } else {
                    // Generate placeholder waveform when no track is loaded
                    wavePoints = DynamicPlaceholderView.generatePlaceholderWaveform(
                        width: 100,
                        timeInterval: Date().timeIntervalSince1970
                    )
                }
            }
            .onAppear {
                if let title = appState.currentTrack?.title {
                    generateWaveform(width: 100, title: title)
                } else {
                    // Generate placeholder waveform when no track is loaded
                    wavePoints = DynamicPlaceholderView.generatePlaceholderWaveform(
                        width: 100,
                        timeInterval: Date().timeIntervalSince1970
                    )
                }
            }
            
            // Time labels
            HStack {
                Text(formatDuration(Double(appState.currentPlaybackSeconds)))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .font(.caption.monospaced())
                
                Spacer()
                
                Text(formatDuration(Double(appState.currentTrack?.durationSeconds ?? 0)))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .font(.caption.monospaced())
            }
        }
    }
    
    private var progress: Double {
        guard let duration = appState.currentTrack?.durationSeconds,
              duration > 0 else { return 0 }
        return Double(appState.currentPlaybackSeconds) / Double(duration)
    }
    
    private func generateWaveform(width: Int, title: String) {
        // Create a hash from the track title
        let titleData = Data(title.utf8)
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
    DurationView()
        .environmentObject(AppState())
        .frame(maxWidth: 400)
        .padding()
        .background(.black)
} 