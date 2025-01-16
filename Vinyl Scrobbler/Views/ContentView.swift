import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            // Album artwork view
            AlbumArtworkView()
                .frame(height: 300)
            
            // Track info
            TrackInfoView()
            
            // Playback controls
            PlaybackControlsView()
            
            // Track list
            TrackListView()
                .frame(maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 800)
        .sheet(isPresented: $appState.showDiscogsSearch) {
            DiscogsSearchView()
                .frame(width: 600, height: 400)
                .background(Color(.windowBackgroundColor))
        }
        .sheet(isPresented: $appState.showLastFMAuth) {
            LastFMAuthView()
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $appState.showAbout) {
            AboutView()
                .frame(width: 360, height: 600)
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
                .frame(width: 400, height: 400)
                .background(Color(.windowBackgroundColor))
        }
        .sheet(isPresented: $appState.showListen) {
            ListenView(isPresented: $appState.showListen)
                .frame(width: 300, height: 500)
                .background(Color(.windowBackgroundColor))
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
} 