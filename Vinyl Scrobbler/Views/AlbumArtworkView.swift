import SwiftUI

struct AlbumArtworkView: View {
    @EnvironmentObject private var appState: AppState
    @State private var artworkImage: Image?
    @State private var previousArtworkImage: Image?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic background that matches artwork
                DynamicBackgroundView(artwork: artworkImage)
                    .transition(.opacity)
                
                // Modern artwork presentation
                VStack {
                    if let track = appState.currentTrack {
                        AsyncImage(url: track.artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                ModernArtworkView(artwork: image)
                                    .onAppear {
                                        previousArtworkImage = artworkImage
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            artworkImage = image
                                        }
                                    }
                            case .failure(_):
                                ModernArtworkView(artwork: nil)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            artworkImage = nil
                                        }
                                    }
                            case .empty:
                                ProgressView()
                                    .controlSize(.large)
                            @unknown default:
                                ModernArtworkView(artwork: nil)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            artworkImage = nil
                                        }
                                    }
                            }
                        }
                    } else {
                        ModernArtworkView(artwork: nil)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    artworkImage = nil
                                }
                            }
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .onChange(of: appState.currentTrack) { oldTrack, newTrack in
            if oldTrack?.artworkURL != newTrack?.artworkURL {
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Clear artwork immediately when track changes
                    artworkImage = nil
                }
            }
        }
    }
}

// MARK: - Preview
struct AlbumArtworkView_Previews: PreviewProvider {
    static var previews: some View {
        AlbumArtworkView()
            .environmentObject(AppState())
            .frame(height: 600)
            .padding()
    }
} 