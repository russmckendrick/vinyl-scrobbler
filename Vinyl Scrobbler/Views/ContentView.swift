import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismissSearch) private var dismissSearch
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    // Album artwork view
                    AlbumArtworkView()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                    
                    // Track info with blur background
                    ScrollView {
                        VStack(spacing: 24) {
                            // Track info
                            TrackInfoView()
                                .padding(.top, 16)
                            
                            // Playback controls
                            PlaybackControlsView()
                            
                            // Track list
                            TrackListView()
                        }
                        .padding(24)
                    }
                    .background(.ultraThinMaterial)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 800)
        .background(Color(.windowBackgroundColor))
        // Sheets
        .sheet(isPresented: $appState.showDiscogsSearch) {
            DiscogsSearchView()
                .frame(width: 600, height: 400)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .sheet(isPresented: $appState.showLastFMAuth) {
            LastFMAuthView()
                .frame(width: 400, height: 300)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .sheet(isPresented: $appState.showAbout) {
            AboutView()
                .frame(width: 360, height: 600)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
                .frame(width: 400, height: 400)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .sheet(isPresented: $appState.showListen) {
            ListenView(isPresented: $appState.showListen)
                .frame(width: 300, height: 500)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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