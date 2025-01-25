import SwiftUI
import Combine
import ScrobbleKit
import UserNotifications

/// Main state management class for the Vinyl Scrobbler application.
/// Handles playback control, Last.fm integration, theme management, and UI state.
/// This class is marked with @MainActor to ensure all UI updates happen on the main thread.
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    /// Currently selected track for playback
    @Published var currentTrack: Track?
    /// List of tracks in the current album/release
    @Published var tracks: [Track] = []
    /// Indicates if a track is currently playing
    @Published var isPlaying = false
    /// Current playback position in seconds
    @Published var currentPlaybackSeconds = 0
    /// Index of the current track in the tracks array
    @Published var currentTrackIndex = 0
    /// Controls visibility of the Discogs search view
    @Published var showDiscogsSearch = false
    /// Controls visibility of the about view
    @Published var showAbout = false
    /// Controls visibility of the Last.fm authentication view
    @Published var showLastFMAuth = false
    /// Controls visibility of the settings view
    @Published var showSettings = false
    /// Controls visibility of the listen view
    @Published var showListen = false
    /// Indicates if the user is authenticated with Last.fm
    @Published var isAuthenticated = false
    /// Current Last.fm user information
    @Published var lastFMUser: SBKUser?
    /// URI for the current Discogs release
    @Published var discogsURI: String?
    /// Controls visibility of the player view
    @Published var showPlayer = true  // Start with the player visible
    /// Tracks actual window visibility
    @Published var windowVisible = true  // Track actual window visibility
    /// Currently selected Discogs release
    @Published var currentRelease: DiscogsRelease?
    /// Current search query for Discogs
    @Published var searchQuery: String = ""  // Add search query property
    /// Current playback position in seconds (as Double for smooth progress updates)
    @Published var currentSeconds: Double = 0
    /// Duration of the current track in seconds
    @Published var duration: Double = 0
    /// Phase value for wave animation
    @Published var wavePhase: Double = 0
    
    // MARK: - App Storage Properties
    
    /// Controls whether artwork should be blurred
    @AppStorage("blurArtwork") var blurArtwork: Bool = false
    /// Controls whether notifications should be shown
    @AppStorage("showNotifications") var showNotifications: Bool = true
    /// Current theme mode setting
    @AppStorage("themeMode") var themeMode: ThemeMode = .system
    
    /// Current theme colors based on selected theme mode
    @Published private(set) var currentTheme: Theme.ThemeColors
    private let theme: Theme
    
    // MARK: - Theme Mode Enum
    
    /// Represents the available theme modes for the application
    enum ThemeMode: String, CaseIterable {
        case light, dark, system
        
        /// Localized display name for each theme mode
        var localizedName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
    }
    
    // MARK: - Private Properties
    
    /// Service for interacting with Last.fm API
    private let lastFMService: LastFMService
    /// Service for interacting with Discogs API
    private let discogsService: DiscogsService
    /// Timer for tracking playback progress
    private var playbackTimer: Timer?
    /// Flag to determine if the current track should be scrobbled
    private var shouldScrobble = false
    
    // MARK: - Initialization
    
    /// Initializes the AppState with default values and required services
    init() {
        // Load theme configuration
        guard let url = Bundle.main.url(forResource: "ColorTheme", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let theme = try? JSONDecoder().decode(Theme.self, from: data) else {
            fatalError("Failed to load theme configuration")
        }
        self.theme = theme
        self.currentTheme = theme.themes.dark // Default to dark theme initially
        
        // Initialize other services
        self.lastFMService = LastFMService.shared
        self.discogsService = DiscogsService.shared
        self.discogsService.configure(with: self)
        
        // Setup theme observation
        setupThemeObservation()
        checkLastFMAuth()
        
        // Request notification permissions
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }
    
    // MARK: - Theme Management
    
    /// Sets up observation of system appearance changes
    private func setupThemeObservation() {
        // Observe system appearance changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateThemeColors),
            name: NSWindow.didChangeOcclusionStateNotification,
            object: nil
        )
        
        // Initial theme update
        updateThemeColors()
    }
    
    /// Updates theme colors based on current theme mode and system appearance
    @objc private func updateThemeColors() {
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        switch themeMode {
        case .light:
            currentTheme = theme.themes.light
        case .dark:
            currentTheme = theme.themes.dark
        case .system:
            currentTheme = isDarkMode ? theme.themes.dark : theme.themes.light
        }
    }
    
    /// Sets the theme mode and updates colors accordingly
    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        updateThemeColors()
    }
    
    // MARK: - Playback Control
    
    /// Toggles play/pause state of the current track
    func togglePlayPause() {
        guard isAuthenticated else {
            showLastFMAuth = true
            return
        }
        
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
            updateNowPlaying()
        } else {
            stopPlayback()
        }
    }
    
    /// Moves to the previous track in the playlist
    func previousTrack() {
        guard isAuthenticated else {
            showLastFMAuth = true
            return
        }
        
        guard currentTrackIndex > 0 else { return }
        // Sort tracks by position before finding the previous track
        let sortedTracks = tracks.sorted { $0.position < $1.position }
        let currentPosition = tracks[currentTrackIndex].position
        if let newIndex = sortedTracks.firstIndex(where: { $0.position == currentPosition }) {
            let previousIndex = newIndex - 1
            if previousIndex >= 0 {
                currentTrackIndex = tracks.firstIndex(where: { $0.position == sortedTracks[previousIndex].position }) ?? (currentTrackIndex - 1)
                currentTrack = tracks[currentTrackIndex]
                resetPlayback()
                updateNowPlaying()
            }
        }
    }
    
    /// Moves to the next track in the playlist
    func nextTrack() {
        guard isAuthenticated else {
            showLastFMAuth = true
            return
        }
        
        guard currentTrackIndex < tracks.count - 1 else { return }
        // Sort tracks by position before finding the next track
        let sortedTracks = tracks.sorted { $0.position < $1.position }
        let currentPosition = tracks[currentTrackIndex].position
        if let newIndex = sortedTracks.firstIndex(where: { $0.position == currentPosition }) {
            let nextIndex = newIndex + 1
            if nextIndex < sortedTracks.count {
                currentTrackIndex = tracks.firstIndex(where: { $0.position == sortedTracks[nextIndex].position }) ?? (currentTrackIndex + 1)
                currentTrack = tracks[currentTrackIndex]
                resetPlayback()
                updateNowPlaying()
            }
        }
    }
    
    /// Starts the playback timer and enables scrobbling
    private func startPlayback() {
        playbackTimer?.invalidate()
        shouldScrobble = true
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlayback()
            }
        }
    }
    
    /// Stops playback and resets playback state
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentPlaybackSeconds = 0
        currentSeconds = 0
        shouldScrobble = false
    }
    
    /// Resets playback state and restarts if currently playing
    private func resetPlayback() {
        currentPlaybackSeconds = 0
        currentSeconds = 0
        shouldScrobble = true
        print("🔄 Reset playback - Scrobbling enabled")
        if isPlaying {
            stopPlayback()
            startPlayback()
        }
    }
    
    /// Updates playback progress and handles scrobbling
    private func updatePlayback() {
        currentPlaybackSeconds += 1
        // Update the current seconds for the progress bar
        currentSeconds = Double(currentPlaybackSeconds)
        
        if let track = currentTrack, let duration = track.durationSeconds {
            self.duration = Double(duration)
        }
        
        // Check for scrobbling threshold (50% of track or 4 minutes)
        if let track = currentTrack,
           let duration = track.durationSeconds,
           shouldScrobble {
            // Only log at significant percentages
            let quarterDuration = duration / 4
            let halfDuration = duration / 2
            let threeQuarterDuration = (duration * 3) / 4
            
            if currentPlaybackSeconds == quarterDuration ||
               currentPlaybackSeconds == halfDuration ||
               currentPlaybackSeconds == threeQuarterDuration {
                print("⏱️ Track progress: \(currentPlaybackSeconds)s / \(duration)s")
            }
            
            if currentPlaybackSeconds >= halfDuration || currentPlaybackSeconds >= 240 {
                print("🎵 Scrobble threshold reached (\(currentPlaybackSeconds)s)")
                scrobbleCurrentTrack()
                shouldScrobble = false  // Prevent multiple scrobbles of the same track
            }
        }
        
        // Handle track completion
        if let track = currentTrack,
           let duration = track.durationSeconds,
           currentPlaybackSeconds >= duration {
            print("✅ Track completed: \(track.title)")
            if currentTrackIndex < tracks.count - 1 {
                nextTrack()
                startPlayback()  // Ensure playback continues
                updateNowPlaying()  // Update Now Playing status for the new track
            } else {
                // Stop playback at the end of the album and reset to first track
                isPlaying = false
                stopPlayback()
                
                // Sort tracks and select the first one
                let sortedTracks = tracks.sorted { $0.position < $1.position }
                if let firstTrack = sortedTracks.first {
                    currentTrack = firstTrack
                    updateCurrentTrackIndex(for: firstTrack)
                }
            }
        }
    }
    
    /// Updates the "Now Playing" status on Last.fm
    private func updateNowPlaying() {
        guard isAuthenticated, let track = currentTrack else { return }
        
        Task {
            do {
                print("🎵 Updating Now Playing: \(track.title)")
                try await lastFMService.updateNowPlaying(track: track)
                sendNowPlayingNotification(for: track)
            } catch {
                print("Failed to update Now Playing: \(error.localizedDescription)")
            }
        }
    }
    
    /// Scrobbles the current track to Last.fm
    private func scrobbleCurrentTrack() {
        guard let track = currentTrack else { return }
        
        Task {
            do {
                try await lastFMService.scrobbleTrack(track: track)
                print("✅ Scrobbled: \(track.title)")
            } catch {
                print("❌ Scrobble failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Checks Last.fm authentication status and updates UI accordingly
    private func checkLastFMAuth() {
        if let sessionKey = lastFMService.getStoredSessionKey(),
           !sessionKey.isEmpty {
            lastFMService.setSessionKey(sessionKey)
            showLastFMAuth = false
            isAuthenticated = true
            Task {
                await fetchUserInfo()
            }
        } else {
            showLastFMAuth = true
            isAuthenticated = false
            lastFMUser = nil
        }
    }
    
    /// Fetches user information from Last.fm
    @MainActor
    func fetchUserInfo() async {
        do {
            lastFMUser = try await lastFMService.getUserInfo()
        } catch {
            print("Failed to fetch user info: \(error.localizedDescription)")
            lastFMUser = nil
        }
    }
    
    /// Signs out the current user and resets application state
    func signOut() {
        // First clear all sheets
        showSettings = false
        showLastFMAuth = false
        showDiscogsSearch = false
        showAbout = false
        showListen = false
        
        // Then clear the session
        lastFMService.clearSession()
        
        // Finally update the authentication state
        isAuthenticated = false
        lastFMUser = nil
        
        // Reset any playback state
        currentTrack = nil
        tracks = []
        isPlaying = false
        currentPlaybackSeconds = 0
        currentTrackIndex = 0
    }
    
    // MARK: - Preview Helpers
    
    #if DEBUG
    /// Convenience initializer for previews with an optional track
    convenience init(previewTrack: Track? = nil) {
        self.init()
        if let track = previewTrack {
            self.currentTrack = track
            self.tracks = [track]
        }
    }
    
    /// Creates a preview state with sample tracks
    static var previewWithTracks: AppState {
        let state = AppState()
        state.tracks = [
            Track(position: "A1", title: "Track One", duration: "3:45", artist: "Artist", album: "Album"),
            Track(position: "A2", title: "Track Two", duration: "4:30", artist: "Artist", album: "Album"),
            Track(position: "A3", title: "Track Three", duration: "5:15", artist: "Artist", album: "Album"),
            Track(position: "B1", title: "Track Four", duration: "3:20", artist: "Artist", album: "Album"),
            Track(position: "B2", title: "Track Five", duration: "4:10", artist: "Artist", album: "Album")
        ]
        state.currentTrack = state.tracks.first
        return state
    }
    #endif
    
    // MARK: - Track Management
    
    /// Updates the current track index based on the track's position
    private func updateCurrentTrackIndex(for track: Track) {
        let sortedTracks = tracks.sorted { $0.position < $1.position }
        if let index = sortedTracks.firstIndex(where: { $0.position == track.position }) {
            currentTrackIndex = tracks.firstIndex(where: { $0.position == sortedTracks[index].position }) ?? 0
        }
    }
    
    /// Selects and starts playing a specific track
    func selectAndPlayTrack(_ track: Track) {
        guard isAuthenticated else {
            showLastFMAuth = true
            return
        }
        
        currentTrack = track
        updateCurrentTrackIndex(for: track)
        resetPlayback()
        isPlaying = true
        startPlayback()
        updateNowPlaying()
    }
    
    /// Loads a Discogs release into the player
    func loadRelease(_ release: DiscogsRelease) {
        guard isAuthenticated else {
            showLastFMAuth = true
            return
        }
        
        print("🎵 Starting to load release: \(release.title)")
        tracks.removeAll()
        
        for trackInfo in release.tracklist {
            // Skip entries that are side titles (have no position)
            guard !trackInfo.position.isEmpty else {
                print("⚠️ Skipping side title: \(trackInfo.title)")
                continue
            }
            
            print("📝 Processing track: \(trackInfo.title) (Position: \(trackInfo.position))")
            
            // Step 1: Check Discogs duration
            var finalDuration: String? = nil
            if let discogsTrackDuration = trackInfo.duration, !discogsTrackDuration.isEmpty {
                print("✅ Found Discogs duration for '\(trackInfo.title)': \(discogsTrackDuration)")
                finalDuration = discogsTrackDuration
            } else {
                print("ℹ️ No Discogs duration for '\(trackInfo.title)', will use default 3:00")
                finalDuration = "3:00"
            }
            
            let track = Track(
                position: trackInfo.position,
                title: trackInfo.title,
                duration: finalDuration,
                artist: release.artists.first?.name ?? "",
                album: release.title,
                artworkURL: nil  // We'll set this later when we get LastFM data
            )
            
            print("""
                ✅ Added track:
                   Position: \(track.position)
                   Title: \(track.title)
                   Duration: \(track.duration ?? "3:00")
                   Artist: \(track.artist)
                """)
            
            tracks.append(track)
        }
        
        // Sort tracks and setup initial state
        tracks.sort { $0.position < $1.position }
        
        if let firstTrack = tracks.first {
            currentTrack = firstTrack
            currentTrackIndex = 0
        }
        
        isPlaying = false
        currentPlaybackSeconds = 0
        shouldScrobble = true
        
        print("✅ Loaded release: \(release.title) with \(tracks.count) tracks")
        
        // After initial load, try to fetch Last.fm durations
        Task {
            await updateTracksWithLastFMDurations(release: release)
        }
    }
    
    /// Updates track durations with Last.fm data after initial load
    private func updateTracksWithLastFMDurations(release: DiscogsRelease) async {
        guard let artist = release.artists.first?.name else { return }
        
        print("🔄 Fetching Last.fm durations for \(release.title)")
        
        do {
            let lastFmAlbumInfo = try await LastFMService.shared.getAlbumInfo(
                artist: artist,
                album: release.title
            )
            print("✅ Got Last.fm album info with \(lastFmAlbumInfo.tracks.count) tracks")
            
            // Get the best quality LastFM artwork URL
            var artworkURL: URL? = nil
            if let images = lastFmAlbumInfo.images {
                if let extraLargeImage = images.first(where: { $0.size == "extralarge" }),
                   let url = URL(string: extraLargeImage.url) {
                    artworkURL = url
                    print("✅ Using Last.fm extra large artwork")
                } else if let largeImage = images.first(where: { $0.size == "large" }),
                          let url = URL(string: largeImage.url) {
                    artworkURL = url
                    print("✅ Using Last.fm large artwork")
                }
            }
            
            // Fallback to Discogs artwork if no LastFM artwork found
            if artworkURL == nil, 
               let firstImage = release.images?.first,
               let url = URL(string: firstImage.uri) {
                artworkURL = url
                print("ℹ️ No Last.fm artwork found, using Discogs artwork")
            }
            
            // Update existing tracks with Last.fm durations and artwork
            for (index, track) in tracks.enumerated() {
                if let matchingLastFmTrack = lastFmAlbumInfo.tracks.first(where: { $0.name.lowercased() == track.title.lowercased() }) {
                    if let duration = matchingLastFmTrack.duration {
                        tracks[index] = Track(
                            position: track.position,
                            title: track.title,
                            duration: duration,
                            artist: track.artist,
                            album: track.album,
                            artworkURL: artworkURL
                        )
                        print("✅ Updated duration for '\(track.title)' with Last.fm duration: \(duration)")
                    }
                } else {
                    // Update artwork even if no duration match found
                    tracks[index] = Track(
                        position: track.position,
                        title: track.title,
                        duration: track.duration,
                        artist: track.artist,
                        album: track.album,
                        artworkURL: artworkURL
                    )
                }
            }
            
            // Update current track if needed
            if let currentIndex = tracks.firstIndex(where: { $0.position == currentTrack?.position }) {
                currentTrack = tracks[currentIndex]
            }
            
        } catch {
            print("❌ Failed to get Last.fm album info: \(error.localizedDescription)")
        }
    }
    
    /// Toggles the visibility of the main window
    func toggleWindowVisibility() {
        windowVisible.toggle()
        showPlayer = windowVisible
        print("🔄 Window visibility toggled: \(windowVisible ? "visible" : "hidden")")
    }
    
    // MARK: - Computed Properties
    
    /// Current playback progress as a percentage
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentSeconds / duration
    }
    
    /// Whether the previous track button should be enabled
    var canPlayPrevious: Bool {
        currentTrackIndex > 0
    }
    
    /// Whether the next track button should be enabled
    var canPlayNext: Bool {
        currentTrackIndex < tracks.count - 1
    }
    
    // MARK: - Notifications
    
    /// Sends a notification when a track starts playing
    private func sendNowPlayingNotification(for track: Track) {
        guard showNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Now Playing"
        content.body = "\(track.title) by \(track.artist)"
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
} 