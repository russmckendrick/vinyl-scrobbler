import SwiftUI

struct TrackListView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List(appState.tracks) { track in
            TrackRow(track: track, isPlaying: isPlaying(track))
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.currentTrack = track
                }
        }
        .listStyle(.inset)
        .frame(minHeight: 200)
        .overlay {
            if appState.tracks.isEmpty {
                ContentUnavailableView(
                    "No Tracks",
                    systemImage: "music.note.list",
                    description: Text("Load an album to see tracks")
                )
            }
        }
    }
    
    private func isPlaying(_ track: Track) -> Bool {
        appState.currentTrack == track && appState.isPlaying
    }
}

// MARK: - Track Row
struct TrackRow: View {
    let track: Track
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Position or playing indicator
            Group {
                if isPlaying {
                    Image(systemName: "play.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Text(track.position)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 24, alignment: .center)
            
            // Track title
            Text(track.title)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Duration
            if let duration = track.duration {
                Text(duration)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .font(.callout)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct TrackListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with tracks
            TrackListView()
                .environmentObject(AppState(previewTrack: Track(
                    position: "A1",
                    title: "Sample Track",
                    duration: "3:45",
                    artist: "Sample Artist",
                    album: "Sample Album"
                )))
                .previewDisplayName("With Tracks")
            
            // Preview without tracks
            TrackListView()
                .environmentObject(AppState())
                .previewDisplayName("No Tracks")
        }
        .frame(height: 400)
        .padding()
    }
}

// MARK: - Preview Helper
extension AppState {
    #if DEBUG
    static var previewWithTracks: AppState {
        let state = AppState()
        state.tracks = [
            Track(position: "A1", title: "Track One", duration: "3:45", artist: "Artist", album: "Album"),
            Track(position: "A2", title: "Track Two", duration: "4:30", artist: "Artist", album: "Album"),
            Track(position: "A3", title: "Track Three", duration: "5:15", artist: "Artist", album: "Album"),
            Track(position: "B1", title: "Track Four", duration: "3:20", artist: "Artist", album: "Album"),
            Track(position: "B2", title: "Track Five", duration: "4:10", artist: "Artist", album: "Album")
        ]
        state.currentTrack = state.tracks.first
        return state
    }
    #endif
} 