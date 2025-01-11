import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            if let track = appState.currentTrack,
               let duration = track.durationSeconds {
                ProgressView(value: Double(appState.currentPlaybackSeconds), total: Double(duration)) {
                    HStack {
                        Text(formatTime(appState.currentPlaybackSeconds))
                            .monospacedDigit()
                        Spacer()
                        Text(formatTime(duration))
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .progressViewStyle(.linear)
                .padding(.horizontal)
            }
            
            // Playback controls
            HStack(spacing: 20) {
                // Previous track button
                Button(action: { appState.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .disabled(appState.currentTrackIndex <= 0)
                
                // Play/Pause button
                Button(action: { appState.togglePlayPause() }) {
                    Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .disabled(appState.tracks.isEmpty)
                
                // Next track button
                Button(action: { appState.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .disabled(appState.currentTrackIndex >= appState.tracks.count - 1)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    PlaybackControlsView()
        .environmentObject(AppState(previewTrack: Track(
            position: "A1",
            title: "Sample Track",
            duration: "3:45",
            artist: "Sample Artist",
            album: "Sample Album"
        )))
} 