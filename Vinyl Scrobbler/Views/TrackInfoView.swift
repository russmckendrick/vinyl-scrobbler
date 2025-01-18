import SwiftUI
import AppKit

struct TrackInfoView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            if let track = appState.currentTrack {
                VStack(alignment: .leading, spacing: 8) {
                    // Track title and metadata group
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("#")
                                .foregroundColor(.secondary)
                            Text(track.position)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text(track.duration ?? "--:--")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        
                        Text(track.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    // Artist and album info
                    VStack(alignment: .leading, spacing: 4) {
                        // Artist name
                        Text(track.artist)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        // Album with Discogs link
                        HStack(spacing: 6) {
                            Text(track.album)
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            if let discogsURLString = appState.discogsURI,
                               let discogsURL = URL(string: discogsURLString) {
                                Link(destination: discogsURL) {
                                    Image(systemName: "link")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.7),
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                // Placeholder when no track is selected
                Text("No Track Selected")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.black.opacity(0.8))
            }
        }
    }
}

#Preview {
    TrackInfoView()
        .environmentObject(AppState())
} 