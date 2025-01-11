import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar and time labels
            VStack(spacing: 4) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    }
                }
                .frame(height: 4)
                
                // Time labels
                HStack {
                    Text(formatTime(appState.currentPlaybackSeconds) ?? "0:00")
                        .monospacedDigit()
                    Spacer()
                    Text(formatTime(currentTrackDuration) ?? "--:--")
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Playback controls
            HStack(spacing: 24) {
                // Previous track button
                Button {
                    appState.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(currentTrackIndex == 0)
                
                // Play/Pause button
                Button {
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(appState.currentTrack == nil)
                
                // Next track button
                Button {
                    appState.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(currentTrackIndex == appState.tracks.count - 1)
            }
            .foregroundColor(.primary)
        }
    }
    
    // MARK: - Helper Properties
    
    private var currentTrackIndex: Int {
        guard let track = appState.currentTrack else { return 0 }
        return appState.tracks.firstIndex(of: track) ?? 0
    }
    
    private var currentTrackDuration: Int? {
        appState.currentTrack?.durationSeconds
    }
    
    // MARK: - Helper Methods
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard let duration = currentTrackDuration, duration > 0 else { return 0 }
        let progress = Double(appState.currentPlaybackSeconds) / Double(duration)
        return totalWidth * progress
    }
    
    private func formatTime(_ seconds: Int?) -> String {
        guard let seconds = seconds else { return "--:--" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Preview
struct PlaybackControlsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with track playing
            PlaybackControlsView()
                .environmentObject(AppState(previewTrack: Track(
                    position: "A1",
                    title: "Sample Track",
                    duration: "3:45",
                    artist: "Sample Artist",
                    album: "Sample Album"
                )))
                .previewDisplayName("With Track")
            
            // Preview without track
            PlaybackControlsView()
                .environmentObject(AppState())
                .previewDisplayName("No Track")
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Custom Button Style
struct PlaybackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
} 