/// ShazamService: A service that provides music recognition functionality using ShazamKit.
/// This service manages audio capture, Shazam matching, and result processing for vinyl record identification.
import Foundation
import ShazamKit
import OSLog
import AVFAudio
import AppKit

// MARK: - Error Handling
/// Comprehensive error types for the Shazam service operations
enum ShazamError: LocalizedError {
    case microphoneAccessDenied
    case recordingFailed
    case matchFailed(Error)
    case noMatch
    case sessionFailed
    case audioEngineError(Error)
    case microphonePermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access is required for music recognition"
        case .recordingFailed:
            return "Failed to start audio recording"
        case .matchFailed(let error):
            return "Failed to match audio: \(error.localizedDescription)"
        case .noMatch:
            return "No match found for the current audio"
        case .sessionFailed:
            return "Failed to initialize Shazam session"
        case .audioEngineError(let error):
            return "Failed to setup audio engine: \(error.localizedDescription)"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        }
    }
}

// MARK: - Match Result
/// Represents a processed match result from Shazam, enriched with additional metadata from Last.fm
struct ShazamMatchResult {
    private static let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ShazamMatchResult")
    
    /// The cleaned-up title of the matched track
    let title: String
    /// The artist name of the matched track
    let artist: String
    /// The album name, either from Last.fm or fallback to track title
    let album: String
    /// List of genres associated with the track
    let genres: [String]
    /// Optional URL to the track on Apple Music
    let appleMusicURL: URL?
    /// Optional URL to the track's artwork
    let artworkURL: URL?
    
    /// Initializes a new ShazamMatchResult from a Shazam match
    /// - Parameter match: The raw match from ShazamKit
    /// - Throws: Error if processing the match fails
    init(from match: SHMatch) async throws {
        let rawTitle = match.mediaItems.first?.title ?? ""
        let rawArtist = match.mediaItems.first?.artist ?? ""
        
        // Clean up the track title and artist
        self.title = Self.cleanupTitle(rawTitle)
        self.artist = rawArtist
        
        // Try to get album info from Last.fm
        do {
            let trackInfo = try await LastFMService.shared.getTrackInfo(
                artist: rawArtist,
                track: self.title
            )
            self.album = trackInfo.album?.title ?? rawTitle
            let albumInfoMessage = "✅ Found album info from Last.fm: " + (trackInfo.album?.title ?? rawTitle)
            Self.logger.info("\(albumInfoMessage)")
        } catch {
            let errorMessage = "⚠️ Failed to get album info from Last.fm: \(error.localizedDescription)"
            Self.logger.warning("\(errorMessage)")
            // If Last.fm lookup fails, use the track title as album
            self.album = rawTitle
        }
        
        self.genres = match.mediaItems.first?.genres ?? []
        self.appleMusicURL = match.mediaItems.first?.appleMusicURL
        self.artworkURL = match.mediaItems.first?.artworkURL
        
        let debugMessage = """
            🎵 Processed Shazam match:
            Track: \(title)
            Artist: \(artist)
            Album: \(album)
            """
        Self.logger.debug("\(debugMessage)")
    }
    
    /// Creates search parameters for Discogs based on the match result
    /// - Returns: Structured search parameters for the Discogs service
    func createDiscogsSearchParameters() -> DiscogsService.SearchParameters {
        DiscogsService.SearchParameters(
            query: "",  // We'll let the struct build this from artist and title
            releaseTitle: self.album,
            artist: self.artist
        )
    }
    
    /// Removes common suffixes and variations from track titles
    /// - Parameter title: The raw title from Shazam
    /// - Returns: A cleaned version of the title without remaster/edition suffixes
    private static func cleanupTitle(_ title: String) -> String {
        // Common suffixes to remove
        let suffixesToRemove = [
            "(Remastered)",
            "(Remastered \\d{4})",  // e.g., (Remastered 2015)
            "\\(\\d{4} Remaster\\)", // e.g., (2015 Remaster)
            "(Deluxe Edition)",
            "(Deluxe Version)",
            "(Deluxe)",
            "(Special Edition)",
            "(Anniversary Edition)",
            "(\\d+th Anniversary Edition)",  // e.g., (50th Anniversary Edition)
            "(Expanded Edition)",
            "(Bonus Track Version)",
            "(Digital Remaster)",
            "(\\d{4} Digital Remaster)",  // e.g., (2009 Digital Remaster)
            "- Remastered",
            "- Remastered \\d{4}",  // e.g., - Remastered 2015
        ]
        
        var cleanTitle = title
        
        // Remove each suffix pattern
        for suffix in suffixesToRemove {
            let regex = try? NSRegularExpression(pattern: suffix + "\\s*$", options: [.caseInsensitive])
            cleanTitle = regex?.stringByReplacingMatches(
                in: cleanTitle,
                options: [],
                range: NSRange(cleanTitle.startIndex..., in: cleanTitle),
                withTemplate: ""
            ) ?? cleanTitle
        }
        
        // Trim any remaining whitespace
        return cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Shazam Service
/// Main service class that handles Shazam integration and audio capture
/// Implements SHSessionDelegate to receive match results from ShazamKit
@MainActor
class ShazamService: NSObject, SHSessionDelegate {
    /// Shared instance for singleton access
    static let shared = ShazamService()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ShazamService")
    
    /// The Shazam session for music recognition
    private var session: SHSession?
    /// Audio engine for capturing input from the microphone
    private var audioEngine: AVAudioEngine?
    /// Flag indicating whether the service is currently listening for matches
    private var isListening: Bool = false
    
    /// Callback handler for match results
    private var matchHandler: ((Result<ShazamMatchResult, Error>) -> Void)?
    
    /// Private initializer for singleton pattern
    private override init() {
        super.init()
        setupSession()
    }
    
    /// Sets up the Shazam session and assigns the delegate
    private func setupSession() {
        session = SHSession()
        session?.delegate = self
        logger.debug("Shazam session initialized")
    }
    
    // MARK: - Audio Recording
    /// Configures the audio engine for microphone capture
    /// - Throws: ShazamError if setup fails
    private func setupAudioEngine() throws {
        logger.info("Setting up audio engine...")
        
        // Initialize audio engine if needed
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        
        guard let audioEngine = audioEngine else {
            logger.error("Failed to create audio engine")
            throw ShazamError.recordingFailed
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        logger.info("Setting up audio capture with format: \(recordingFormat)")
        
        // Remove existing tap if any
        inputNode.removeTap(onBus: 0)
        
        // Install new tap with larger buffer size
        inputNode.installTap(onBus: 0, 
                           bufferSize: 2048, 
                           format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, time: AVAudioTime) in
            guard let self = self,
                  let session = self.session else { return }
            
            // Only process buffer if we're actively listening
            guard self.isListening else { return }
            
            // Calculate audio level for debugging (optional)
            let level = buffer.rms()
            if level > 0.1 { // Only log significant audio levels
                self.logger.debug("Receiving audio: Level = \(level)")
            }
            
            session.matchStreamingBuffer(buffer, at: time)
        }
        
        // Prepare engine before starting
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            logger.info("✅ Audio engine started successfully")
        } catch {
            logger.error("❌ Failed to start audio engine: \(error.localizedDescription)")
            throw ShazamError.audioEngineError(error)
        }
    }
    
    /// Checks and requests microphone permission if needed
    /// - Throws: ShazamError if permission is denied
    private func checkMicrophonePermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            logger.info("Microphone permission already granted")
            return
        case .notDetermined:
            logger.info("Requesting microphone permission...")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if granted {
                logger.info("✅ Microphone permission granted")
                return
            }
            throw ShazamError.microphonePermissionDenied
        case .denied, .restricted:
            logger.error("❌ Microphone permission denied")
            throw ShazamError.microphonePermissionDenied
        @unknown default:
            throw ShazamError.microphonePermissionDenied
        }
    }
    
    // MARK: - Public Interface
    /// Starts listening for audio to match
    /// - Throws: Error if microphone access is denied or setup fails
    func startListening() async throws {
        guard !isListening else {
            logger.debug("Already listening, ignoring start request")
            return
        }
        
        // Check microphone permission first
        try await checkMicrophonePermission()
        
        do {
            logger.debug("Setting up audio engine...")
            try setupAudioEngine()
            isListening = true
            logger.info("🎤 Started listening for audio matches")
        } catch {
            logger.error("❌ Audio setup failed: \(error.localizedDescription)")
            throw ShazamError.recordingFailed
        }
    }
    
    /// Stops listening and cleans up audio resources
    func stopListening() {
        guard isListening else { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil  // Release the engine
        isListening = false
        logger.info("Stopped listening for audio matches")
    }
    
    // MARK: - SHSessionDelegate
    /// Called when Shazam finds a match for the current audio
    /// - Parameters:
    ///   - session: The Shazam session
    ///   - match: The found match
    nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        Task { @MainActor in
            guard !match.mediaItems.isEmpty else {
                logger.warning("Received match with no media items")
                matchHandler?(.failure(ShazamError.noMatch))
                return
            }
            
            do {
                let result = try await ShazamMatchResult(from: match)
                logger.info("Found match: \(result.title) from album \(result.album) by \(result.artist)")
                matchHandler?(.success(result))
            } catch {
                logger.error("Failed to process match: \(error.localizedDescription)")
                matchHandler?(.failure(error))
            }
        }
    }
    
    /// Called when Shazam fails to find a match
    /// - Parameters:
    ///   - session: The Shazam session
    ///   - signature: The audio signature that failed to match
    ///   - error: Optional error describing why the match failed
    nonisolated func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Match failed: \(error.localizedDescription)")
                matchHandler?(.failure(ShazamError.matchFailed(error)))
            } else {
                logger.warning("No match found")
                matchHandler?(.failure(ShazamError.noMatch))
            }
        }
    }
    
    // MARK: - Match Handling
    /// Listens for a single match and returns the result
    /// - Returns: A processed ShazamMatchResult
    /// - Throws: Error if matching fails
    func listenForMatch() async throws -> ShazamMatchResult {
        try await startListening()
        
        return try await withCheckedThrowingContinuation { continuation in
            matchHandler = { result in
                self.stopListening()
                switch result {
                case .success(let match):
                    continuation.resume(returning: match)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - AVAudioPCMBuffer Extension
/// Extension to calculate audio levels from PCM buffer
extension AVAudioPCMBuffer {
    /// Calculates the root mean square (RMS) of the audio buffer
    /// - Returns: The RMS value as a Float
    func rms() -> Float {
        guard let channelData = self.floatChannelData else { return 0 }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = Array(UnsafeBufferPointer(start: channelDataValue,
                                                            count: Int(self.frameLength)))
        let squares = channelDataValueArray.map { $0 * $0 }
        let sum = squares.reduce(0, +)
        let mean = sum / Float(self.frameLength)
        return sqrt(mean)
    }
}