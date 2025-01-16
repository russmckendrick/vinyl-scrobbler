import Foundation
import SwiftUI
import OSLog

@MainActor
class ListenViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ListenViewModel")
    
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var currentStatus: ListeningStatus = .idle
    @Published var animationAmount = 1.0
    @Published var matchedTrack = ""
    @Published var matchedArtist = ""
    @Published var matchedAlbum = ""
    @Published var isPresented: Bool
    
    // MARK: - Services
    private let shazamService = ShazamService.shared
    private let lastFMService = LastFMService.shared
    private let discogsService = DiscogsService.shared
    private var appState: AppState?
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = Published(initialValue: isPresented.wrappedValue)
    }
    
    func setAppState(_ state: AppState) {
        self.appState = state
    }
    
    // MARK: - Computed Properties
    var buttonTitle: String {
        switch currentStatus {
        case .found:
            return "Search Discogs"
        case .listening:
            return "Stop Listening"
        default:
            return "Start Listening"
        }
    }
    
    var buttonColor: Color {
        switch currentStatus {
        case .found:
            return .blue
        case .listening:
            return .red
        default:
            return .blue
        }
    }
    
    // MARK: - Status Management
    enum ListeningStatus {
        case idle
        case listening
        case matching
        case searching
        case found
        case error
        
        var message: String {
            switch self {
            case .idle:
                return "Ready to Listen"
            case .listening:
                return "Listening for Music..."
            case .matching:
                return "Found Something! Identifying..."
            case .searching:
                return "Searching Album Details..."
            case .found:
                return "Match Found!"
            case .error:
                return "Error Occurred"
            }
        }
        
        var systemImage: String {
            switch self {
            case .idle:
                return "waveform.circle"
            case .listening:
                return "waveform"
            case .matching:
                return "shazam.logo"
            case .searching:
                return "magnifyingglass"
            case .found:
                return "checkmark.circle"
            case .error:
                return "exclamationmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .idle:
                return .secondary
            case .listening:
                return .blue
            case .matching:
                return .purple
            case .searching:
                return .orange
            case .found:
                return .green
            case .error:
                return .red
            }
        }
    }
    
    // MARK: - Public Methods
    func startListening() async {
        do {
            withAnimation {
                currentStatus = .listening
                isListening = true
                startPulseAnimation()
            }
            
            // Start Shazam listening
            let match = try await shazamService.listenForMatch()
            
            withAnimation {
                currentStatus = .matching
            }
            
            // Get additional track info from Last.fm
            withAnimation {
                currentStatus = .searching
            }
            
            let trackInfo = try await lastFMService.getTrackInfo(
                artist: match.artist,
                track: match.title
            )
            
            withAnimation {
                currentStatus = .found
                isListening = false
                stopPulseAnimation()
                matchedTrack = trackInfo.name
                matchedArtist = trackInfo.artist.name
                matchedAlbum = trackInfo.album?.title ?? ""
            }
        } catch {
            handleError(error)
        }
    }
    
    func searchDiscogs() {
        // Set up the search query
        let searchQuery = "\(matchedArtist) - \(matchedAlbum)"
        logger.info("🔍 Opening Discogs search for: \(searchQuery)")
        
        // Update app state
        appState?.searchQuery = searchQuery
        
        // Close the Listen view and update app state
        isPresented = false
        appState?.showListen = false
        
        // Show Discogs search after a brief delay to ensure Listen view is closed
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            appState?.showDiscogsSearch = true
        }
    }
    
    func stopListening() {
        withAnimation {
            shazamService.stopListening()
            isListening = false
            currentStatus = .idle
            stopPulseAnimation()
        }
    }
    
    // MARK: - Private Methods
    private func handleError(_ error: Error) {
        withAnimation {
            isListening = false
            currentStatus = .error
            stopPulseAnimation()
            
            if let shazamError = error as? ShazamError {
                errorMessage = shazamError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
        
        // Reset after delay
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation {
                currentStatus = .idle
                showError = false
            }
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            animationAmount = 1.2
        }
    }
    
    private func stopPulseAnimation() {
        withAnimation {
            animationAmount = 1.0
        }
    }
} 