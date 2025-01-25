/// TrackInfoView: A SwiftUI view that displays detailed information about the currently
/// selected track. It shows track position, duration, title, artist, and album information
/// with optional Discogs integration for additional album details. The view adapts its
/// appearance based on the current theme and handles both track-loaded and no-track states.
import SwiftUI

/// A view that displays comprehensive track information with themed styling
struct TrackInfoView: View {
    /// Access to the global app state for track information and theming
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            if let track = appState.currentTrack {
                // Track metadata section showing position and duration
                HStack(spacing: 8) {
                    // Track position indicator
                    Text("#")
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                        .font(.system(size: 16, weight: .medium))
                    Text(track.position)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                    
                    // Duration indicator with clock icon
                    Image(systemName: "clock")
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(track.duration ?? "--:--")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                }
                
                // Primary track title display
                Text(track.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(appState.currentTheme.foreground.primary)
                    .multilineTextAlignment(.center)
                
                // Artist and album information with optional Discogs link
                HStack(spacing: 4) {
                    // Artist name
                    Text(track.artist)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                    
                    // Separator between artist and album
                    Text("-")
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                        .font(.system(size: 18, weight: .medium))
                    
                    // Album name
                    Text(track.album)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                    
                    // Optional Discogs link button
                    if appState.discogsURI != nil {
                        Button {
                            if let url = URL(string: appState.discogsURI!) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 14))
                                .foregroundStyle(appState.currentTheme.foreground.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Placeholder state when no track is selected
                Text("No Track Selected")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
            }
        }
        // Container styling
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

/// Preview provider for TrackInfoView
/// Demonstrates the view with a preview app state and themed background
#Preview {
    let previewState = AppState()
    return TrackInfoView()
        .environmentObject(previewState)
        .frame(maxWidth: 400)
        .padding()
        .background(previewState.currentTheme.background.primary)
}