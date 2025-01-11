import SwiftUI

struct AlbumArtworkView: View {
    @EnvironmentObject private var appState: AppState
    @State private var artworkImage: NSImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
                .shadow(radius: 2)
            
            if isLoading {
                // Loading state
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)
            } else if let image = artworkImage {
                // Album artwork
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .transition(.opacity)
            } else {
                // Placeholder
                VStack {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Album Loaded")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: appState.currentTrack) { _ in
            loadArtwork()
        }
    }
    
    private func loadArtwork() {
        guard let track = appState.currentTrack else {
            artworkImage = nil
            return
        }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                // Get album info from Last.fm
                let albumInfo = try await LastFMService.shared.getAlbumInfo(
                    artist: track.artist,
                    album: track.album
                )
                
                // Get the largest image URL
                if let imageUrl = albumInfo.images?.last?.url,
                   let url = URL(string: imageUrl) {
                    // Load the image
                    let image = try await DiscogsService.shared.fetchImage(url: url)
                    await MainActor.run {
                        withAnimation {
                            self.artworkImage = image
                        }
                    }
                }
            } catch {
                print("Failed to load artwork: \(error)")
                await MainActor.run {
                    self.artworkImage = nil
                }
            }
        }
    }
}

// MARK: - Preview
struct AlbumArtworkView_Previews: PreviewProvider {
    static var previews: some View {
        AlbumArtworkView()
            .frame(width: 300, height: 300)
            .environmentObject(AppState())
    }
} 