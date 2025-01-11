import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    
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
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
        }
        .task {
            // Request notification permissions on first launch
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState(previewTrack: Track(
                position: "A1",
                title: "Sample Track",
                duration: "3:45",
                artist: "Sample Artist",
                album: "Sample Album"
            )))
    }
} 