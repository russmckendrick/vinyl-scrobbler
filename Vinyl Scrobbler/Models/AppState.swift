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
            if currentTrackIndex < tracks.count - 1 {
                nextTrack()
                startPlayback()  // Ensure playback continues
                updateNowPlaying()
            } else {
                // Stop playback at the end of the album
                isPlaying = false
                stopPlayback()
            }
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
} 