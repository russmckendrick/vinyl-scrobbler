import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            // Album artwork
            AlbumArtworkView()
                .frame(width: 300, height: 300)
            
            // Track info
            TrackInfoView()
            
            // Playback controls
            PlaybackControlsView()
            
            // Track list
            TrackListView()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 700)
        .sheet(isPresented: $appState.showDiscogsSearch) {
            DiscogsSearchView()
        }
        .sheet(isPresented: $appState.showLastFMAuth) {
            LastFMAuthView()
        }
        .sheet(isPresented: $appState.showAbout) {
            AboutView()
        }
    }
} 