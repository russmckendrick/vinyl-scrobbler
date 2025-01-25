/// ContentView: The main view of the Vinyl Scrobbler application that serves as the
/// root container for all major components. It manages the layout of album artwork,
/// playback controls, track information, and various modal sheets for different features.
import SwiftUI

/// The root view container that orchestrates the main UI components and modal presentations
struct ContentView: View {
    /// Access to the global app state for managing UI state and theming
    @EnvironmentObject private var appState: AppState
    /// Environment value to programmatically dismiss search
    @Environment(\.dismissSearch) private var dismissSearch
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base background with slight transparency
                appState.currentTheme.background.primary
                    .opacity(0.95)
                    .ignoresSafeArea()
                
                // Main content container with vertical layout
                VStack(spacing: 0) {
                    // Album artwork section with overlaid track list
                    ZStack(alignment: .bottom) {
                        // Full-width artwork display
                        AlbumArtworkView()
                            .frame(width: geometry.size.width, height: geometry.size.width)
                        
                        // Overlaid track list with horizontal padding
                        TrackListView()
                            .padding(.horizontal)
                    }
                    
                    // Lower content area containing track info and controls
                    VStack(spacing: 0) {
                        // Flexible spacing around track information
                        Spacer()
                        TrackInfoView()
                        Spacer()
                        
                        // Bottom control section
                        VStack(spacing: 16) {
                            // Playback control buttons
                            PlaybackControlsView()
                                .padding(.horizontal, 40)  // Wider spacing for controls
                            
                            // Track duration indicator
                            DurationView()
                                .padding(.bottom, 16)
                        }
                    }
                    .padding(.horizontal, 24)
                    .background(appState.currentTheme.background.primary)
                }
            }
            // Main window styling
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(appState.currentTheme.border.primary, lineWidth: 0.5)
            )
        }
        .frame(minWidth: 500, minHeight: 800)
        
        // MARK: - Modal Sheets
        
        // Discogs search sheet
        .sheet(isPresented: $appState.showDiscogsSearch) {
            DiscogsSearchView()
                .frame(width: 600, height: 400)
                .background(appState.currentTheme.background.overlay)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(appState.currentTheme.border.primary, lineWidth: 0.5)
                )
                .overlay(alignment: .topTrailing) {
                    // Close button for Discogs search
                    Button {
                        appState.showDiscogsSearch = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        
        // Last.fm authentication sheet
        .sheet(isPresented: $appState.showLastFMAuth) {
            LastFMAuthView()
                .frame(width: 400, height: 300)
                .background(appState.currentTheme.background.overlay)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(appState.currentTheme.border.primary, lineWidth: 0.5)
                )
                .overlay(alignment: .topTrailing) {
                    // Close button for Last.fm auth
                    Button {
                        appState.showLastFMAuth = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        
        // About view sheet
        .sheet(isPresented: $appState.showAbout) {
            AboutView()
                .frame(width: 360, height: 600)
                .background(appState.currentTheme.background.overlay)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(appState.currentTheme.border.primary, lineWidth: 0.5)
                )
                .overlay(alignment: .topTrailing) {
                    // Close button for About view
                    Button {
                        appState.showAbout = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        
        // Settings sheet
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
                .frame(width: 400, height: 400)
                .background(appState.currentTheme.background.overlay)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(appState.currentTheme.border.primary, lineWidth: 0.5)
                )
                .overlay(alignment: .topTrailing) {
                    // Close button for Settings
                    Button {
                        appState.showSettings = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        
        // Listen view sheet
        .sheet(isPresented: $appState.showListen) {
            ListenView(isPresented: $appState.showListen)
                .frame(width: 300, height: 500)
                .background(appState.currentTheme.background.overlay)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(appState.currentTheme.border.primary, lineWidth: 0.5)
                )
                .overlay(alignment: .topTrailing) {
                    // Close button for Listen view
                    Button {
                        appState.showListen = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
        }
    }
}

/// Preview provider for ContentView
#Preview {
    ContentView()
        .environmentObject(AppState())
}