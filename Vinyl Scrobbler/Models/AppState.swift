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
    @Published var isAuthenticated = false
    @Published var lastFMUser: SBKUser?
    
    private let lastFMService: LastFMService
    private let discogsService: DiscogsService
    private var playbackTimer: Timer?
    private var shouldScrobble = false
    
    init() {
        self.lastFMService = LastFMService.shared
        self.discogsService = DiscogsService.shared
        checkLastFMAuth()
        
        // Request notification permission
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
            updateNowPlaying()
        } else {
            stopPlayback()
        }
    }
    
    func previousTrack() {
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
        shouldScrobble = false
    }
    
    private func resetPlayback() {
        currentPlaybackSeconds = 0
        shouldScrobble = true
        print("🔄 Reset playback - Scrobbling enabled")
        if isPlaying {
            stopPlayback()
            startPlayback()
        }
    }
    
    private func updatePlayback() {
        currentPlaybackSeconds += 1
        
        // Check for scrobbling threshold (50% of track or 4 minutes)
        if let track = currentTrack,
           let duration = track.durationSeconds,
           shouldScrobble {
            // Only log at significant percentages
            if currentPlaybackSeconds == duration / 4 ||
               currentPlaybackSeconds == duration / 2 ||
               currentPlaybackSeconds == (duration * 3) / 4 {
                print("⏱️ Track progress: \(currentPlaybackSeconds)s / \(duration)s")
            }
            
            if currentPlaybackSeconds >= duration / 2 || currentPlaybackSeconds >= 240 {
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
        guard isAuthenticated, let track = currentTrack else { return }
        
        Task {
            do {
                print("📝 Scrobbling track: \(track.title)")
                try await lastFMService.scrobbleTrack(track: track)
                print("✅ Successfully scrobbled: \(track.title)")
                
                // Check if notifications are enabled
                if UserDefaults.standard.bool(forKey: "enableNotifications") {
                    let content = UNMutableNotificationContent()
                    content.title = "Track Scrobbled"
                    content.subtitle = track.title
                    content.body = "\(track.artist) - \(track.album)"
                    
                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString,
                        content: content,
                        trigger: nil
                    )
                    
                    try? await UNUserNotificationCenter.current().add(request)
                }
            } catch {
                print("❌ Failed to scrobble track: \(error.localizedDescription)")
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
    
    private func fetchUserInfo() async {
        do {
            lastFMUser = try await lastFMService.getUserInfo()
        } catch {
            print("Failed to fetch user info: \(error.localizedDescription)")
            lastFMUser = nil
        }
    }
    
    func signOut() {
        lastFMService.clearSession()
        isAuthenticated = false
        showLastFMAuth = true
        lastFMUser = nil
    }
    
    #if DEBUG
    convenience init(previewTrack: Track? = nil) {
        self.init()
        if let track = previewTrack {
            self.currentTrack = track
            self.tracks = [track]
        }
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
        currentTrack = track
        updateCurrentTrackIndex(for: track)
        resetPlayback()
        isPlaying = true
        startPlayback()
        updateNowPlaying()
    }
} 