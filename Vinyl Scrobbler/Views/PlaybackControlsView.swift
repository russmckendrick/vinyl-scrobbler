import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 40) {
            // Previous track button
            Button {
                appState.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(!appState.canPlayPrevious ? appState.currentTheme.foreground.tertiary : appState.currentTheme.foreground.primary)
            .disabled(!appState.canPlayPrevious)
            
            // Play/Pause button
            Button {
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }
            .buttonStyle(.plain)
            .foregroundStyle(appState.tracks.isEmpty ? appState.currentTheme.foreground.tertiary : appState.currentTheme.foreground.primary)
            .disabled(appState.tracks.isEmpty)
            .shadow(color: appState.currentTheme.artwork.shadow, radius: 10)
            
            // Next track button
            Button {
                appState.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(!appState.canPlayNext ? appState.currentTheme.foreground.tertiary : appState.currentTheme.foreground.primary)
            .disabled(!appState.canPlayNext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#Preview {
    let previewState = AppState()
    return PlaybackControlsView()
        .environmentObject(previewState)
        .frame(maxWidth: 400)
        .padding()
        .background(previewState.currentTheme.background.primary)
} 