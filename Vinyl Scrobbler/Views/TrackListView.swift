/// TrackListView: A SwiftUI view that displays an expandable list of tracks
/// with interactive playback controls. Features a collapsible interface with
/// a handle bar, track count indicator, and a scrollable list of tracks.
/// Includes visual feedback for the currently playing track and supports
/// direct track selection for playback.
import SwiftUI

/// Main view for displaying the track list with expansion capabilities
struct TrackListView: View {
    /// Access to the global app state for track data and theming
    @EnvironmentObject private var appState: AppState
    /// Namespace for coordinating animations between views
    @Namespace private var animation
    /// Controls the expanded/collapsed state of the track list
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Interactive handle bar with track count display
            HStack {
                // Visual handle for dragging/expanding
                Capsule()
                    .fill(appState.currentTheme.foreground.secondary.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.vertical, 8)
                
                Spacer()
                
                // Track count indicator when tracks are present
                if !appState.tracks.isEmpty {
                    Text("\(appState.tracks.count) Tracks")
                        .font(.caption)
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                // Animate expansion/collapse with spring effect
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            
            // Expandable track list section
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Efficient rendering of tracks with alternating backgrounds
                        ForEach(Array(appState.tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRow(track: track, isPlaying: appState.currentTrack?.id == track.id)
                                .background(index % 2 == 0 ? appState.currentTheme.background.secondary : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    appState.selectAndPlayTrack(track)
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        // Visual styling for the container
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(appState.currentTheme.background.primary.opacity(0.4))
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .shadow(color: appState.currentTheme.artwork.shadow, radius: 15, y: -8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Individual row view for displaying track information
/// Provides visual feedback for the currently playing track
struct TrackRow: View {
    /// Access to the global app state for theming
    @EnvironmentObject private var appState: AppState
    /// Track data to display
    let track: Track
    /// Indicates if this track is currently playing
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Track position or playing indicator
            HStack(spacing: 4) {
                if isPlaying {
                    // Play icon for current track
                    Image(systemName: "play.fill")
                        .foregroundStyle(appState.currentTheme.foreground.primary)
                        .font(.caption)
                } else {
                    // Position number for non-playing tracks
                    Text(track.position)
                        .foregroundStyle(appState.currentTheme.foreground.primary.opacity(0.7))
                        .font(.caption.monospaced())
                }
            }
            .frame(width: 24, alignment: .leading)
            
            // Track title with dynamic styling
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .foregroundStyle(isPlaying ? appState.currentTheme.foreground.primary : appState.currentTheme.foreground.primary.opacity(0.9))
                    .font(.callout)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Track duration display
            Text(track.duration ?? "--:--")
                .foregroundStyle(appState.currentTheme.foreground.primary.opacity(0.7))
                .font(.caption.monospaced())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isPlaying ? appState.currentTheme.foreground.primary.opacity(0.1) : Color.clear)
    }
}

/// Preview provider for TrackListView
/// Demonstrates the view with a preview app state and themed background
#Preview {
    let previewState = AppState()
    return TrackListView()
        .environmentObject(previewState)
        .frame(maxWidth: 400)
        .background(previewState.currentTheme.background.primary)
}