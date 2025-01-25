/// ListenViewModel: A view model that manages the music listening and recognition functionality.
/// This class coordinates between ShazamKit for music recognition, Last.fm for metadata,
/// and Discogs for vinyl record lookup.
import Foundation
import SwiftUI
import OSLog

/// Main view model for the listening feature that handles music recognition and search coordination
@MainActor
class ListenViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ListenViewModel")
    
    // MARK: - Published Properties
    /// Indicates if the app is currently listening for music
    @Published var isListening = false
    /// Indicates if a search operation is in progress
    @Published var isSearching = false
    /// Stores error messages for display
    @Published var errorMessage: String?
    /// Controls the visibility of error messages
    @Published var showError = false
    /// Current status of the listening process
    @Published var currentStatus: ListeningStatus = .idle
    /// Controls the pulse animation amount
    @Published var animationAmount = 1.0
    /// The title of the matched track
    @Published var matchedTrack = ""
    /// The artist name of the matched track
    @Published var matchedArtist = ""
    /// The album name of the matched track
    @Published var matchedAlbum = ""
    /// Controls the presentation of the listen view
    @Published var isPresented: Bool
    
    // MARK: - Services
    /// Service for music recognition using ShazamKit
    private let shazamService = ShazamService.shared
    /// Service for fetching additional track metadata from Last.fm
    private let lastFMService = LastFMService.shared
    /// Service for searching vinyl records on Discogs
    private let discogsService = DiscogsService.shared
    /// Reference to the global app state
    private var appState: AppState?
    
    /// Initializes the view model with a presentation binding
    /// - Parameter isPresented: Binding to control the view's presentation
    init(isPresented: Binding<Bool>) {
        self._isPresented = Published(initialValue: isPresented.wrappedValue)
    }
    
    /// Sets the app state reference
    /// - Parameter state: The global app state
    func setAppState(_ state: AppState) {
        self.appState = state
    }
    
    // MARK: - Computed Properties
    /// Returns the appropriate button title based on the current status
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
    
    /// Returns the appropriate button color based on the current status
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
    /// Represents the various states of the listening process
    enum ListeningStatus {
        case idle
        case listening
        case matching
        case searching
        case found
        case error
        
        /// User-friendly message for each status
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
        
        /// System image name for each status
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
        
        /// Color associated with each status
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
    /// Starts the music recognition process
    /// This method coordinates between Shazam for recognition and Last.fm for metadata
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
    
    /// Initiates a Discogs search for the matched track
    /// This method transitions from the listening view to the Discogs search view
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
    
    /// Stops the music recognition process and resets the UI
    func stopListening() {
        withAnimation {
            shazamService.stopListening()
            isListening = false
            currentStatus = .idle
            stopPulseAnimation()
        }
    }
    
    // MARK: - Private Methods
    /// Handles errors that occur during the listening process
    /// - Parameter error: The error that occurred
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
    
    /// Starts the pulse animation for the listening indicator
    private func startPulseAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            animationAmount = 1.2
        }
    }
    
    /// Stops the pulse animation
    private func stopPulseAnimation() {
        withAnimation {
            animationAmount = 1.0
        }
    }
}