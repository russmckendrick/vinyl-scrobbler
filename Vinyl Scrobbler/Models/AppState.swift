import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var currentTrack: Track?
    @Published var tracks: [Track] = []
    @Published var isPlaying = false
    @Published var currentPlaybackSeconds = 0
    @Published var showDiscogsSearch = false
    @Published var showAbout = false
    @Published var showLastFMAuth = false
    
    private let lastFMService: LastFMService
    private let discogsService: DiscogsService
    private var playbackTimer: Timer?
    
    init() {
        // Initialize services on the main actor
        self.lastFMService = LastFMService.shared
        self.discogsService = DiscogsService.shared
        
        // Check auth state
        checkLastFMAuth()
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }
    
    func previousTrack() {
        guard let currentIndex = getCurrentTrackIndex(),
              currentIndex > 0 else { return }
        currentTrack = tracks[currentIndex - 1]
        resetPlayback()
    }
    
    func nextTrack() {
        guard let currentIndex = getCurrentTrackIndex(),
              currentIndex < tracks.count - 1 else { return }
        currentTrack = tracks[currentIndex + 1]
        resetPlayback()
    }
    
    private func getCurrentTrackIndex() -> Int? {
        guard let currentTrack = currentTrack else { return nil }
        return tracks.firstIndex(where: { $0.id == currentTrack.id })
    }
    
    private func startPlayback() {
        // Create timer on main actor
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlayback()
            }
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func resetPlayback() {
        currentPlaybackSeconds = 0
        if isPlaying {
            stopPlayback()
            startPlayback()
        }
    }
    
    private func updatePlayback() {
        currentPlaybackSeconds += 1
        
        // Handle track completion
        if let track = currentTrack,
           let duration = track.durationSeconds,
           currentPlaybackSeconds >= duration {
            nextTrack()
        }
    }
    
    private func checkLastFMAuth() {
        Task {
            let sessionKey = await lastFMService.getStoredSessionKey()
            if sessionKey == nil || sessionKey?.isEmpty == true {
                showLastFMAuth = true
            }
        }
    }
    
    #if DEBUG
    // Simple preview helper
    convenience init(previewTrack: Track? = nil) {
        self.init()
        if let track = previewTrack {
            self.currentTrack = track
            self.tracks = [track]
        }
    }
    #endif
} 