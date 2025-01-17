import SwiftUI
import Combine
import ScrobbleKit
import UserNotifications

@MainActor
class AppState: ObservableObject {
    @Published var currentTrack: Track?
    @Published var tracks: [Track] = []
    @Published var isPlaying = false
    @Published var currentPlaybackSeconds = 0
    @Published var currentTrackIndex = 0
    @Published var showDiscogsSearch = false
    @Published var showAbout = false
    @Published var showLastFMAuth = false
    @Published var showSettings = false
    @Published var showListen = false
    @Published var isAuthenticated = false
    @Published var lastFMUser: SBKUser?
    @Published var discogsURI: String?
    @Published var showPlayer = true  // Start with the player visible
    @Published var windowVisible = true  // Track actual window visibility
    @Published var currentRelease: DiscogsRelease?
    @Published var searchQuery: String = ""  // Add search query property
    @Published var currentSeconds: Double = 0
    @Published var duration: Double = 0
    @Published var wavePhase: Double = 0
    
    @AppStorage("blurArtwork") var blurArtwork: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("themeMode") var themeMode: ThemeMode = .system
    
    @Published private(set) var currentTheme: Theme.ThemeColors
    private let theme: Theme
    
    enum ThemeMode: String, CaseIterable {
        case light, dark, system
        
        var localizedName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
    }
    
    private let lastFMService: LastFMService
    private let discogsService: DiscogsService
    private var playbackTimer: Timer?
    private var shouldScrobble = false
    
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
        
        // Request notification permission
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }
    
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
    
    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        updateThemeColors()
    }
    
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
    
    private func startPlayback() {
        playbackTimer?.invalidate()
        shouldScrobble = true
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlayback()
            }
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentPlaybackSeconds = 0
        currentSeconds = 0
        shouldScrobble = false
    }
    
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
    
    private func updateNowPlaying() {
        guard isAuthenticated, let track = currentTrack else { return }
        
        Task {
            do {
                print("🎵 Updating Now Playing: \(track.title)")
                try await lastFMService.updateNowPlaying(track: track)
            } catch {
                print("Failed to update Now Playing: \(error.localizedDescription)")
            }
        }
    }
    
    private func scrobbleCurrentTrack() {
        guard let track = currentTrack else { return }
        
        Task {
            do {
                try await lastFMService.scrobbleTrack(track: track)
                print("✅ Scrobbled: \(track.title)")
                sendScrobbleNotification(for: track)
            } catch {
                print("❌ Scrobble failed: \(error.localizedDescription)")
            }
        }
    }
    
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
    
    @MainActor
    func fetchUserInfo() async {
        do {
            lastFMUser = try await lastFMService.getUserInfo()
        } catch {
            print("Failed to fetch user info: \(error.localizedDescription)")
            lastFMUser = nil
        }
    }
    
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
    
    #if DEBUG
    convenience init(previewTrack: Track? = nil) {
        self.init()
        if let track = previewTrack {
            self.currentTrack = track
            self.tracks = [track]
        }
    }
    
    // MARK: - Preview Helpers
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
    
    // Helper method to update currentTrackIndex based on sorted position
    private func updateCurrentTrackIndex(for track: Track) {
        let sortedTracks = tracks.sorted { $0.position < $1.position }
        if let index = sortedTracks.firstIndex(where: { $0.position == track.position }) {
            currentTrackIndex = tracks.firstIndex(where: { $0.position == sortedTracks[index].position }) ?? 0
        }
    }
    
    // Update this method to handle track selection
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
    
    public func createTracks(from release: DiscogsRelease) async {
        var newTracks: [Track] = []
        
        for track in release.tracklist {
            var duration = track.duration
            var artworkURL: URL? = nil
            
            // Fetch artwork and duration from Last.fm
            do {
                let albumInfo = try await LastFMService.shared.getAlbumInfo(artist: release.artists.first?.name ?? "", album: release.title)
                if let images = albumInfo.images {
                    if let extraLargeImage = images.first(where: { $0.size == "extralarge" }) {
                        artworkURL = URL(string: extraLargeImage.url)
                    } else if let largeImage = images.first(where: { $0.size == "large" }) {
                        artworkURL = URL(string: largeImage.url)
                    }
                }
                
                // Fetch duration from Last.fm
                if let lastFmTrack = albumInfo.tracks.first(where: { $0.name == track.title }),
                   let durationStr = lastFmTrack.duration,
                   let durationSeconds = Int(durationStr) {
                    let minutes = durationSeconds / 60
                    let seconds = durationSeconds % 60
                    duration = String(format: "%d:%02d", minutes, seconds)
                }
            } catch {
                print("Failed to get album info from Last.fm: \(error.localizedDescription)")
            }
            
            // Fallback to "3:00" if no duration is available
            if duration == nil || duration?.isEmpty == true {
                duration = "3:00"
            }
            
            // Fallback to Discogs artwork if Last.fm artwork is not available
            if artworkURL == nil {
                artworkURL = URL(string: release.images?.first?.uri ?? "")
            }
            
            let newTrack = Track(
                position: track.position,
                title: track.title,
                duration: duration,
                artist: release.artists.first?.name ?? "",
                album: release.title,
                artworkURL: artworkURL
            )
            newTracks.append(newTrack)
        }
        
        tracks = newTracks
        if !tracks.isEmpty {
            currentTrackIndex = 0
            currentTrack = tracks[currentTrackIndex]
        }
    }
    
    func loadRelease(_ release: DiscogsRelease) {
        guard isAuthenticated else {
            showLastFMAuth = true
            return
        }
        
        // Clear existing tracks
        tracks.removeAll()
        
        // Create tracks from release
        for track in release.tracklist {
            let newTrack = Track(
                position: track.position,
                title: track.title,
                duration: track.duration?.isEmpty ?? true ? "3:00" : track.duration,
                artist: release.artists.first?.name ?? "",
                album: release.title,
                artworkURL: release.images?.first.map { URL(string: $0.uri) } ?? nil
            )
            tracks.append(newTrack)
        }
        
        // Sort tracks by position
        tracks.sort { $0.position < $1.position }
        
        // Set initial track
        if let firstTrack = tracks.first {
            currentTrack = firstTrack
            currentTrackIndex = 0
        }
        
        // Reset playback state
        isPlaying = false
        currentPlaybackSeconds = 0
        shouldScrobble = true
        
        print("✅ Loaded release: \(release.title) with \(tracks.count) tracks")
    }
    
    func toggleWindowVisibility() {
        windowVisible.toggle()
        showPlayer = windowVisible
        print("🔄 Window visibility toggled: \(windowVisible ? "visible" : "hidden")")
    }
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentSeconds / duration
    }
    
    var canPlayPrevious: Bool {
        currentTrackIndex > 0
    }
    
    var canPlayNext: Bool {
        currentTrackIndex < tracks.count - 1
    }
    
    private func sendScrobbleNotification(for track: Track) {
        guard showNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Track Scrobbled"
        content.body = "\(track.title) by \(track.artist)"
        content.sound = .default
        
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