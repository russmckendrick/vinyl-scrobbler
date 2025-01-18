import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismissSearch) private var dismissSearch
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base background
                Color.black
                    .opacity(0.95)
                    .ignoresSafeArea()
                
                // Main content container
                VStack(spacing: 0) {
                    // Album artwork view
                    AlbumArtworkView()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                    
                    // Content area
                    ScrollView {
                        VStack(spacing: 16) {
                            TrackInfoView()
                            
                            PlaybackControlsView()
                            
                            TrackListView()
                                .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                    .background(Color.black)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .frame(minWidth: 500, minHeight: 800)
        // Sheets with consistent styling
        .sheet(isPresented: $appState.showDiscogsSearch) {
            DiscogsSearchView()
                .frame(width: 600, height: 400)
                .background(Color(nsColor: .black).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
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
                .background(Color(nsColor: .black).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
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
                .background(Color(nsColor: .black).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
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
                .background(Color(nsColor: .black).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
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
                .background(Color(nsColor: .black).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
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

#Preview {
    ContentView()
        .environmentObject(AppState())
} 