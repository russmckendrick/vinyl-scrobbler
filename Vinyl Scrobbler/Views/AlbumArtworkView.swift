/// AlbumArtworkView: A SwiftUI view that displays album artwork with dynamic loading states,
/// blur effects, and themed overlays. This view handles various states including loading,
/// success, and failure scenarios while maintaining smooth transitions between states.
import SwiftUI

/// A view component that displays album artwork with dynamic loading and visual effects
struct AlbumArtworkView: View {
    /// Access to the global app state for theming and track information
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        GeometryReader { geometry in
            // Check for current track and artwork URL availability
            if let track = appState.currentTrack,
               let artworkURL = track.artworkURL {
                // Asynchronously load and display the artwork image
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .empty:
                        // Display placeholder while loading
                        DynamicPlaceholderView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .transition(.opacity)  // Fade transition for loading state
                    case .success(let image):
                        // Display successfully loaded artwork
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: appState.blurArtwork ? 20 : 0)  // Conditional blur effect
                            .clipped()  // Prevent image overflow
                            .overlay(
                                // Themed gradient overlay for visual consistency
                                LinearGradient(
                                    colors: appState.currentTheme.artwork.overlay.gradient,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .transition(.opacity)  // Smooth transition when artwork changes
                    case .failure(_):
                        // Display placeholder on load failure
                        DynamicPlaceholderView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .transition(.opacity)
                    @unknown default:
                        // Future-proof handling of new loading states
                        DynamicPlaceholderView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .transition(.opacity)
                    }
                }
            } else {
                // Display placeholder when no track or artwork URL is available
                DynamicPlaceholderView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .transition(.opacity)
            }
        }
        // Extend view beyond safe area for edge-to-edge display
        .ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
        // Smooth animations for artwork and blur changes
        .animation(.easeInOut, value: appState.currentTrack?.artworkURL)
        .animation(.easeInOut, value: appState.blurArtwork)
    }
}

/// Preview provider for AlbumArtworkView
#Preview {
    let previewState = AppState()
    return AlbumArtworkView()
        .environmentObject(previewState)
        .frame(width: 400, height: 400)
        .background(previewState.currentTheme.background.primary)
}