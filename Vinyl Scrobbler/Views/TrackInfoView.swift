import SwiftUI

struct TrackInfoView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 8) {
            if let track = appState.currentTrack {
                // Track title
                Text(track.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Album title
                HStack(spacing: 8) {
                    Text(track.album)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Discogs icon
                    if let discogsURLString = appState.discogsURI, let discogsURL = URL(string: discogsURLString) {
                        Link(destination: discogsURL) {
                            Image(systemName: "link.circle")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Artist name
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Track duration and position
                HStack(spacing: 12) {
                    Label(track.position, systemImage: "number")
                        .foregroundColor(.secondary)
                    
                    if let duration = track.duration {
                        Label(duration, systemImage: "clock")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                .padding(.top, 4)
            } else {
                // Placeholder when no track is selected
                Text("No Track Selected")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .animation(.easeInOut, value: appState.currentTrack)
    }
}

// MARK: - Preview
struct TrackInfoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with track
            TrackInfoView()
                .environmentObject(AppState())
        }
    }
} 