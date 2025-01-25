/// PlaybackControlsView: A SwiftUI view that provides playback control buttons
/// for managing track playback. It includes previous, play/pause, and next buttons
/// with dynamic styling based on playback state and track availability.
/// The view integrates with the app's state management to control playback and
/// reflect the current playback status through visual feedback.
import SwiftUI

/// A view that displays and manages playback control buttons
struct PlaybackControlsView: View {
    /// Access to the global app state for playback control and theming
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 40) {
            // Previous track button with dynamic styling
            // Disabled when no previous track is available
            Button {
                appState.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(!appState.canPlayPrevious ? appState.currentTheme.foreground.tertiary : appState.currentTheme.foreground.primary)
            .disabled(!appState.canPlayPrevious)
            
            // Central play/pause button with dynamic icon
            // Changes between play and pause icons based on playback state
            // Disabled when no tracks are available
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
            
            // Next track button with dynamic styling
            // Disabled when no next track is available
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
        // Container styling for the control group
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// Preview provider for PlaybackControlsView
/// Demonstrates the controls in a themed environment
#Preview {
    let previewState = AppState()
    return PlaybackControlsView()
        .environmentObject(previewState)
        .frame(maxWidth: 400)
        .padding()
        .background(previewState.currentTheme.background.primary)
}