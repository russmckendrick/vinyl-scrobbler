import Foundation
import OSLog
import CryptoKit
import ScrobbleKit

// MARK: - Extensions
// Add MD5 hashing capability to String for Last.fm API authentication
extension String {
    var md5: String {
        let computed = Insecure.MD5.hash(data: self.data(using: .utf8)!)
        return computed.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - Error Handling
// Custom errors for Last.fm API operations
enum LastFMError: LocalizedError {
    case configurationMissing
    case invalidSessionKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case authenticationFailed(Error)
    case missingApiKey
    
    var errorDescription: String? {
        // Error descriptions for user-friendly messages
        switch self {
        case .configurationMissing:
            return "Last.fm configuration is missing"
        case .invalidSessionKey:
            return "Invalid session key - Please re-authenticate"
        case .invalidURL:
            return "Invalid URL for Last.fm API request"
        case .invalidResponse:
            return "Invalid response from Last.fm API"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode) from Last.fm API"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .authenticationFailed(let error):
            return "Failed to authenticate with Last.fm: \(error.localizedDescription)"
        case .missingApiKey:
            return "Missing Last.fm API key"
        }
    }
}

// MARK: - Response Models
// Models for parsing Last.fm API responses
struct LastFMResponse: Codable {
    let album: AlbumInfo
}

// Album information from Last.fm
struct AlbumInfo: Codable {
    let name: String
    let artist: String
    let url: URL?
    let playcount: Int?
    let listeners: Int?
    let tracks: [AlbumTrack]
    let wiki: String?
    let images: [AlbumImage]?
    
    // Custom coding keys for JSON mapping
    private enum CodingKeys: String, CodingKey {
        case name, artist, url, playcount, listeners, tracks, wiki
        case images = "image"
    }
    
    // Custom decoder to handle Last.fm's nested JSON structure
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        artist = try container.decode(String.self, forKey: .artist)
        url = try? container.decode(URL.self, forKey: .url)
        playcount = try? container.decode(Int.self, forKey: .playcount)
        listeners = try? container.decode(Int.self, forKey: .listeners)
        
        // Handle tracks wrapper
        if let tracksWrapper = try? container.decode(TracksWrapper.self, forKey: .tracks) {
            tracks = tracksWrapper.track
        } else {
            tracks = []
        }
        
        // Handle wiki wrapper
        if let wikiWrapper = try? container.decode(WikiWrapper.self, forKey: .wiki) {
            wiki = wikiWrapper.summary
        } else {
            wiki = nil
        }
        
        // Handle images
        if let imageArray = try? container.decode([AlbumImage].self, forKey: .images) {
            images = imageArray
        } else {
            images = nil
        }
    }
}

// Wrapper structures for nested JSON
struct TracksWrapper: Codable {
    let track: [AlbumTrack]
}

struct WikiWrapper: Codable {
    let summary: String
}

// Album artwork information
struct AlbumImage: Codable {
    let url: String
    let size: String
    
    private enum CodingKeys: String, CodingKey {
        case url = "#text"
        case size
    }
}

// Track information from Last.fm
struct AlbumTrack: Codable {
    let name: String
    let duration: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case duration
    }
    
    // Custom decoder to handle duration conversion
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if let durationSeconds = try container.decodeIfPresent(Int.self, forKey: .duration), durationSeconds > 0 {
            let minutes = durationSeconds / 60
            let seconds = durationSeconds % 60
            duration = String(format: "%d:%02d", minutes, seconds)
        } else {
            duration = "3:00"  // Default duration if not provided
        }
    }
}

// MARK: - Last.fm Service
// Main service class for Last.fm API interactions
@MainActor
class LastFMService {
    // Singleton instance
    @MainActor static let shared = LastFMService()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "LastFMService")
    private let session: URLSession
    private var manager: SBKManager?
    
    // MARK: - Initialization
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
        setupScrobbleKit()
    }
    
    // Configure ScrobbleKit with API credentials
    private func setupScrobbleKit() {
        guard let apiKey = SecureConfig.lastFMAPIKey,
              let secret = SecureConfig.lastFMSecret else {
            logger.error("Failed to load Last.fm configuration")
            return
        }
        
        manager = SBKManager(
            apiKey: apiKey,
            secret: secret
        )
        
        // Check keychain for existing session key
        if let sessionKey = getStoredSessionKey() {
            manager?.setSessionKey(sessionKey)
            logger.info("Loaded existing Last.fm session key from keychain")
        }
    }
    
    // MARK: - Authentication
    // Authenticate user with Last.fm
    func authenticate(username: String, password: String) async throws {
        guard let manager = manager else {
            throw LastFMError.configurationMissing
        }
        
        do {
            // Get session from ScrobbleKit
            let response = try await manager.startSession(username: username, password: password)
            
            // Store session key in keychain
            try await storeSessionKey(response.key)
            
            // Set the session key in manager
            manager.setSessionKey(response.key)
            
            logger.info("Authentication successful")
        } catch {
            logger.error("Authentication failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Store session key securely in keychain
    private func storeSessionKey(_ key: String) async throws {
        // First remove any existing key
        let removeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lastfm_session_key"
        ]
        SecItemDelete(removeQuery as CFDictionary)
        
        // Store new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lastfm_session_key",
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw LastFMError.authenticationFailed(NSError(domain: "com.vinyl.scrobbler", 
                                                         code: Int(status)))
        }
    }
    
    // MARK: - Scrobbling
    // Submit track play to Last.fm
    public func scrobbleTrack(track: AppDelegate.Track) async throws {
        guard let manager = manager else {
            throw LastFMError.configurationMissing
        }
        
        let durationInSeconds = convertDurationToSeconds(track.duration)
        
        logger.debug("""
            📝 Preparing to scrobble track:
            Title: \(track.title)
            Artist: \(track.artist)
            Album: \(track.album)
            Duration: \(track.duration ?? "unknown") (\(String(describing: durationInSeconds)) seconds)
            """)
        
        do {
            let sbkTrack = SBKTrackToScrobble(
                artist: track.artist,
                track: track.title,
                timestamp: Date(),  // Use current time for scrobble
                album: track.album,
                duration: durationInSeconds ?? 0
            )
            
            let response = try await manager.scrobble(tracks: [sbkTrack])
            
            if response.isCompletelySuccessful {
                logger.info("✅ Track successfully submitted to Last.fm")
            } else if let result = response.results.first {
                if result.isAccepted {
                    var correctionLog = ["🔄 Track scrobbled with the following corrections:"]
                    if let correctedArtist = result.correctedArtist {
                        correctionLog.append("- Artist corrected to: \(correctedArtist)")
                    }
                    if let correctedTrack = result.correctedTrack {
                        correctionLog.append("- Track corrected to: \(correctedTrack)")
                    }
                    if let correctedAlbum = result.correctedAlbum {
                        correctionLog.append("- Album corrected to: \(correctedAlbum)")
                    }
                    logger.info("\(correctionLog.joined(separator: "\n"))")
                } else if let error = result.error {
                    logger.error("❌ Scrobble rejected by Last.fm: \(error.rawValue)")
                    throw LastFMError.invalidResponse
                }
            }
        } catch {
            logger.error("❌ Scrobble failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Update Now Playing information
    public func updateNowPlaying(track: AppDelegate.Track) async throws {
        guard let manager = manager else {
            throw LastFMError.configurationMissing
        }
        
        let durationInSeconds = convertDurationToSeconds(track.duration)
        
        logger.debug("""
            🎵 Updating Now Playing:
            Title: \(track.title)
            Artist: \(track.artist)
            Album: \(track.album)
            Duration: \(track.duration ?? "unknown") (\(String(describing: durationInSeconds)) seconds)
            """)
        
        do {
            let result = try await manager.updateNowPlaying(
                artist: track.artist,
                track: track.title,
                album: track.album,
                duration: durationInSeconds
            )
            
            logger.info("✅ Now Playing updated on Last.fm")
            
            // Log any corrections
            if !result.correctedInformation.isEmpty {
                var correctionLog = ["🔄 Last.fm made the following corrections:"]
                if let artist = result.correctedInformation[.artist] {
                    correctionLog.append("- Artist: \(artist)")
                }
                if let track = result.correctedInformation[.track] {
                    correctionLog.append("- Track: \(track)")
                }
                if let album = result.correctedInformation[.album] {
                    correctionLog.append("- Album: \(album)")
                }
                if let albumArtist = result.correctedInformation[.albumArtist] {
                    correctionLog.append("- Album Artist: \(albumArtist)")
                }
                logger.info("\(correctionLog.joined(separator: "\n"))")
            }
        } catch {
            logger.error("❌ Failed to update Now Playing: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Scrobble track with specific timestamp
    public func scrobbleArtist(artist: String, track: String, album: String, duration: Int, timestamp: Date) async throws {
        guard let manager = manager else {
            throw LastFMError.configurationMissing
        }
        
        do {
            logger.info("Scrobbling track: '\(track)' by \(artist) from album '\(album)'")
            
            let trackToScrobble = SBKTrackToScrobble(
                artist: artist,
                track: track,
                timestamp: timestamp,
                album: album,
                duration: duration
            )
            
            let response = try await manager.scrobble(tracks: [trackToScrobble])
            
            if response.isCompletelySuccessful {
                logger.info("Track scrobbled successfully!")
            } else {
                if let result = response.results.first {
                    if result.isAccepted {
                        logger.info("Scrobbled: \(result.track.artist) - \(result.track.track)")
                        if let correctedArtist = result.correctedArtist {
                            logger.info("Artist corrected to: \(correctedArtist)")
                        }
                        if let correctedTrack = result.correctedTrack {
                            logger.info("Track corrected to: \(correctedTrack)")
                        }
                    } else if let error = result.error {
                        logger.error("Failed to scrobble \(result.track.artist) - \(result.track.track): \(error.rawValue)")
                        throw LastFMError.authenticationFailed(error)
                    }
                }
            }
        } catch {
            logger.error("Failed to scrobble track: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Album Information
    // Fetch album details from Last.fm
    public func getAlbumInfo(artist: String, album: String) async throws -> AlbumInfo {
        guard let apiKey = SecureConfig.lastFMAPIKey else {
            throw LastFMError.missingApiKey
        }
        
        var components = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")
        components?.queryItems = [
            URLQueryItem(name: "method", value: "album.getInfo"),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "album", value: album),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components?.url else {
            throw LastFMError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LastFMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LastFMError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(LastFMResponse.self, from: data)
            return result.album
        } catch {
            logger.error("Failed to decode Last.fm response: \(error.localizedDescription)")
            throw LastFMError.decodingError(error)
        }
    }
    
    // MARK: - Utility Methods
    // Convert duration string to seconds
    private func convertDurationToSeconds(_ duration: String?) -> Int? {
        guard let duration = duration else { return nil }
        let components = duration.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return nil
        }
        return minutes * 60 + seconds
    }
    
    // MARK: - Session Management
    // Set active session key
    public func setSessionKey(_ key: String) {
        manager?.setSessionKey(key)
        logger.info("Set Last.fm session key (length: \(key.count) characters)")
    }
    
    // Retrieve stored session key from keychain
    public func getStoredSessionKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lastfm_session_key",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            logger.info("✅ Retrieved session key from keychain")
            return key
        }
        
        logger.info("ℹ️ No session key found in keychain")
        return nil
    }
    
    // Start new session with credentials
    public func startSession(username: String, password: String) async throws -> (key: String?, name: String?) {
        guard let manager = manager else {
            throw LastFMError.configurationMissing
        }
        
        do {
            logger.info("🔐 Attempting to authenticate with Last.fm for user: \(username)")
            let response = try await manager.startSession(username: username, password: password)
            
            // Verify we got a valid session key
            guard !response.key.isEmpty else {
                logger.error("❌ Received empty session key from Last.fm")
                throw LastFMError.invalidSessionKey
            }
            
            // Set the session key in the manager
            manager.setSessionKey(response.key)
            
            // Store the session key in keychain
            do {
                try await storeSessionKey(response.key)
            } catch {
                logger.error("❌ Failed to store session key: \(error.localizedDescription)")
                // Continue even if keychain storage fails - we still have the key in memory
            }
            
            logger.info("✅ Successfully authenticated with Last.fm")
            return (response.key, response.name)
            
        } catch {
            logger.error("❌ Authentication failed with error: \(error.localizedDescription)")
            throw LastFMError.authenticationFailed(error)
        }
    }
    
    // Clear current session
    @MainActor
    func clearSession() {
        manager?.setSessionKey("")
        logger.info("Cleared Last.fm session")
    }
}
