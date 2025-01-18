import SwiftUI

struct TrackInfoView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            if let track = appState.currentTrack {
                // Track position and duration
                HStack(spacing: 8) {
                    Text("#")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                    Text(track.position)
                        .font(.system(size: 16, weight: .medium))
                    
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                    Text(track.duration ?? "--:--")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.secondary)
                
                // Track title
                Text(track.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Artist and Album with link
                HStack(spacing: 4) {
                    Text(track.artist)
                        .font(.system(size: 18, weight: .medium))
                    
                    Text("-")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18, weight: .medium))
                    
                    Text(track.album)
                        .font(.system(size: 18, weight: .medium))
                    
                    if appState.discogsURI != nil {
                        Button {
                            if let url = URL(string: appState.discogsURI!) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.secondary)
            } else {
                Text("No Track Selected")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

#Preview {
    TrackInfoView()
        .environmentObject(AppState.previewWithTracks)
        .frame(maxWidth: 400)
        .padding()
        .background(.black)
} 