import SwiftUI
import AppKit
import CryptoKit

struct PlaybackControlsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var wavePhase: CGFloat = 0
    @State private var wavePoints: [CGPoint] = []
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar and time
            if let track = appState.currentTrack,
               let duration = track.durationSeconds {
                VStack(spacing: 8) {
                    // Custom progress bar with waveform
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            WaveformView(points: wavePoints)
                                .fill(.secondary.opacity(0.2))
                                .frame(height: 32)
                            
                            // Progress
                            WaveformView(points: wavePoints)
                                .fill(Color.white)
                                .frame(width: geometry.size.width * progress(current: appState.currentPlaybackSeconds, total: duration), height: 32)
                                .clipShape(Rectangle())
                        }
                    }
                    .frame(height: 32)
                    .onChange(of: track.title) { _, _ in
                        generateWaveform(width: 100, track: track)
                    }
                    .onAppear {
                        generateWaveform(width: 100, track: track)
                    }
                    
                    // Time labels
                    HStack {
                        Text(formatTime(appState.currentPlaybackSeconds))
                            .monospacedDigit()
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(duration))
                            .monospacedDigit()
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Playback controls
            HStack(spacing: 40) {
                // Previous track button
                Button(action: { appState.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundColor(appState.currentTrackIndex > 0 ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(appState.currentTrackIndex <= 0)
                
                // Play/Pause button
                Button(action: { appState.togglePlayPause() }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.black)
                        }
                }
                .buttonStyle(.plain)
                .disabled(appState.tracks.isEmpty)
                
                // Next track button
                Button(action: { appState.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(appState.currentTrackIndex < appState.tracks.count - 1 ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(appState.currentTrackIndex >= appState.tracks.count - 1)
            }
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.9),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func generateWaveform(width: Int, track: Track) {
        // Create a hash from the track title
        let titleData = Data(track.title.utf8)
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
    
    private func progress(current: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current) / CGFloat(total)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct WaveformView: Shape {
    var points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        guard !points.isEmpty else { return Path() }
        
        let path = Path { p in
            // Scale points to the actual size
            let scaledPoints = points.map { point in
                CGPoint(
                    x: point.x * rect.width,
                    y: point.y * rect.height
                )
            }
            
            p.move(to: CGPoint(x: 0, y: rect.height / 2))
            
            // Draw the top curve through all points
            for i in 0..<scaledPoints.count - 1 {
                let current = scaledPoints[i]
                let next = scaledPoints[i + 1]
                let control = CGPoint(
                    x: (current.x + next.x) / 2,
                    y: (current.y + next.y) / 2
                )
                p.addQuadCurve(to: next, control: control)
            }
            
            // Complete the path
            p.addLine(to: CGPoint(x: rect.width, y: rect.height))
            p.addLine(to: CGPoint(x: 0, y: rect.height))
            p.closeSubpath()
        }
        return path
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
    PlaybackControlsView()
        .environmentObject(AppState())
        .frame(width: 400)
        .background(.black)
} 