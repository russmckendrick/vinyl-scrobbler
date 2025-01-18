import SwiftUI

struct AlbumArtworkView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        GeometryReader { geometry in
            if let track = appState.currentTrack,
               let artworkURL = track.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .empty:
                        DynamicPlaceholderView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .transition(.opacity)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: appState.blurArtwork ? 20 : 0)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: appState.currentTheme.artwork.overlay.gradient,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .transition(.opacity)
                    case .failure(_):
                        DynamicPlaceholderView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .transition(.opacity)
                    @unknown default:
                        DynamicPlaceholderView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .transition(.opacity)
                    }
                }
            } else {
                DynamicPlaceholderView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
        .animation(.easeInOut, value: appState.currentTrack?.artworkURL)
        .animation(.easeInOut, value: appState.blurArtwork)
    }
}

#Preview {
    let previewState = AppState()
    return AlbumArtworkView()
        .environmentObject(previewState)
        .frame(width: 400, height: 400)
        .background(previewState.currentTheme.background.primary)
} 