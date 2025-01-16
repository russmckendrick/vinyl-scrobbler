import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismissSearch) private var dismissSearch
    
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
        .sheet(isPresented: $appState.showDiscogsSearch, onDismiss: {
            print("Discogs search dismissed")
        }) {
            DiscogsSearchView()
                .frame(width: 600, height: 400)
                .background(Color(.windowBackgroundColor))
                .overlay(alignment: .topTrailing) {
                    Button {
                        appState.showDiscogsSearch = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        .sheet(isPresented: $appState.showLastFMAuth, onDismiss: {
            print("LastFM auth dismissed")
        }) {
            LastFMAuthView()
                .frame(width: 400, height: 300)
                .overlay(alignment: .topTrailing) {
                    Button {
                        appState.showLastFMAuth = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        .sheet(isPresented: $appState.showAbout, onDismiss: {
            print("About dismissed")
        }) {
            AboutView()
                .frame(width: 360, height: 600)
                .overlay(alignment: .topTrailing) {
                    Button {
                        appState.showAbout = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        .sheet(isPresented: $appState.showSettings, onDismiss: {
            print("Settings dismissed")
        }) {
            SettingsView()
                .frame(width: 400, height: 400)
                .background(Color(.windowBackgroundColor))
                .overlay(alignment: .topTrailing) {
                    Button {
                        appState.showSettings = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        .sheet(isPresented: $appState.showListen, onDismiss: {
            print("Listen dismissed")
        }) {
            ListenView(isPresented: $appState.showListen)
                .frame(width: 300, height: 500)
                .background(Color(.windowBackgroundColor))
                .overlay(alignment: .topTrailing) {
                    Button {
                        appState.showListen = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
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