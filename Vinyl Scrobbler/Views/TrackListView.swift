import SwiftUI

struct TrackListView: View {
    @EnvironmentObject private var appState: AppState
    @Namespace private var animation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar and track count
            HStack {
                Capsule()
                    .fill(appState.currentTheme.foreground.secondary.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.vertical, 8)
                
                Spacer()
                
                if !appState.tracks.isEmpty {
                    Text("\(appState.tracks.count) Tracks")
                        .font(.caption)
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            
            // Track list
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
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

struct TrackRow: View {
    @EnvironmentObject private var appState: AppState
    let track: Track
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Position and playing indicator
            HStack(spacing: 4) {
                if isPlaying {
                    Image(systemName: "play.fill")
                        .foregroundStyle(appState.currentTheme.foreground.primary)
                        .font(.caption)
                } else {
                    Text(track.position)
                        .foregroundStyle(appState.currentTheme.foreground.primary.opacity(0.7))
                        .font(.caption.monospaced())
                }
            }
            .frame(width: 24, alignment: .leading)
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .foregroundStyle(isPlaying ? appState.currentTheme.foreground.primary : appState.currentTheme.foreground.primary.opacity(0.9))
                    .font(.callout)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(track.duration ?? "--:--")
                .foregroundStyle(appState.currentTheme.foreground.primary.opacity(0.7))
                .font(.caption.monospaced())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isPlaying ? appState.currentTheme.foreground.primary.opacity(0.1) : Color.clear)
    }
}

#Preview {
    let previewState = AppState()
    return TrackListView()
        .environmentObject(previewState)
        .frame(maxWidth: 400)
        .background(previewState.currentTheme.background.primary)
} 