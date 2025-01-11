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
    
    private let lastFMService: LastFMService
    private let discogsService: DiscogsService
    private var playbackTimer: Timer?
    
    init() {
        self.lastFMService = LastFMService.shared
        self.discogsService = DiscogsService.shared
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
        guard currentTrackIndex > 0 else { return }
        currentTrackIndex -= 1
        currentTrack = tracks[currentTrackIndex]
        resetPlayback()
    }
    
    func nextTrack() {
        guard currentTrackIndex < tracks.count - 1 else { return }
        currentTrackIndex += 1
        currentTrack = tracks[currentTrackIndex]
        resetPlayback()
    }
    
    private func startPlayback() {
        playbackTimer?.invalidate()
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
        if let sessionKey = lastFMService.getStoredSessionKey(),
           !sessionKey.isEmpty {
            showLastFMAuth = false
        } else {
            showLastFMAuth = true
        }
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