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
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .clear,
                                        .clear,
                                        .black.opacity(0.3),
                                        .black.opacity(0.6),
                                        .black
                                    ],
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
    }
}

#Preview {
    AlbumArtworkView()
        .environmentObject(AppState())
        .frame(width: 400, height: 400)
        .background(.black)
} 