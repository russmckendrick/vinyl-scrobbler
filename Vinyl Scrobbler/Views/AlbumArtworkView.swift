import SwiftUI

struct AlbumArtworkView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ZStack {
            if let track = appState.currentTrack {
                // Show album artwork if available
                AsyncImage(url: track.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    // Show placeholder while loading
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                }
            } else {
                // Show empty state
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                    Text("No Album Loaded")
                }
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct AlbumArtworkView_Previews: PreviewProvider {
    static var previews: some View {
        AlbumArtworkView()
            .environmentObject(AppState())
            .frame(height: 300)
            .padding()
    }
} 