import SwiftUI
import Combine

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
    @Published var isAuthenticated = false
    
    private let lastFMService: LastFMService
    private let discogsService: DiscogsService
    private var playbackTimer: Timer?
    private var shouldScrobble = false
    
    init() {
        self.lastFMService = LastFMService.shared
        self.discogsService = DiscogsService.shared
        checkLastFMAuth()
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
        currentTrackIndex -= 1
        currentTrack = tracks[currentTrackIndex]
        resetPlayback()
        updateNowPlaying()
    }
    
    func nextTrack() {
        guard currentTrackIndex < tracks.count - 1 else { return }
        currentTrackIndex += 1
        currentTrack = tracks[currentTrackIndex]
        resetPlayback()
        updateNowPlaying()
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
           shouldScrobble,
           (currentPlaybackSeconds >= duration / 2 || currentPlaybackSeconds >= 240) {
            scrobbleCurrentTrack()
            shouldScrobble = false  // Prevent multiple scrobbles of the same track
        }
        
        // Handle track completion
        if let track = currentTrack,
           let duration = track.durationSeconds,
           currentPlaybackSeconds >= duration {
            nextTrack()
        }
    }
    
    private func updateNowPlaying() {
        guard isAuthenticated, let track = currentTrack else { return }
        
        Task {
            do {
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
                try await lastFMService.scrobbleTrack(track: track)
                print("Successfully scrobbled: \(track.title)")
            } catch {
                print("Failed to scrobble track: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkLastFMAuth() {
        if let sessionKey = lastFMService.getStoredSessionKey(),
           !sessionKey.isEmpty {
            lastFMService.setSessionKey(sessionKey)
            showLastFMAuth = false
            isAuthenticated = true
        } else {
            showLastFMAuth = true
            isAuthenticated = false
        }
    }
    
    func signOut() {
        lastFMService.clearSession()
        isAuthenticated = false
        showLastFMAuth = true
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
} 