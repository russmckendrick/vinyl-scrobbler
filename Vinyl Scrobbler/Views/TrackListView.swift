import SwiftUI

struct TrackListView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List(appState.tracks) { track in
            TrackRow(track: track, isPlaying: isPlaying(track))
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectTrack(track)
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
    
    private func selectTrack(_ track: Track) {
        appState.selectAndPlayTrack(track)
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
                .environmentObject(AppState())
        }
    }
} 