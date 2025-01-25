/// Service class for handling all Last.fm API interactions including authentication,
/// scrobbling, track information retrieval, and user management.
/// This service uses both direct Last.fm API calls and the ScrobbleKit framework.
import Foundation
import OSLog
import CryptoKit
import ScrobbleKit

// MARK: - Error Handling

/// Represents possible errors that can occur during Last.fm API operations
enum LastFMError: LocalizedError {
    /// Configuration data (API key, secret) is missing
    case configurationMissing
    /// The session key is invalid or expired
    case invalidSessionKey
    /// The constructed URL for the API request is invalid
    case invalidURL
    /// The API response was not in the expected format
    case invalidResponse
    /// The API request returned an HTTP error
    case httpError(Int)
    /// Failed to decode the API response
    case decodingError(Error)
    /// Authentication with Last.fm failed
    case authenticationFailed(Error)
    /// The Last.fm API key is missing from configuration
    case missingApiKey
    
    var errorDescription: String? {
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

/// Root response structure for album information requests
struct LastFMResponse: Codable {
    let album: AlbumInfo
}

/// Detailed album information from Last.fm API
struct AlbumInfo: Codable {
    /// Album name
    let name: String
    /// Artist name
    let artist: String
    /// Last.fm URL for the album
    let url: URL?
    /// Number of times the album has been played
    let playcount: Int?
    /// Number of Last.fm users who have listened to the album
    let listeners: Int?
    /// List of tracks in the album
    let tracks: [AlbumTrack]
    /// Album description/wiki content
    let wiki: String?
    /// Album artwork in various sizes
    let images: [AlbumImage]?
    
    private enum CodingKeys: String, CodingKey {
        case name, artist, url, playcount, listeners, tracks, wiki
        case images = "image"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        artist = try container.decode(String.self, forKey: .artist)
        url = try? container.decode(URL.self, forKey: .url)
        playcount = try? container.decode(Int.self, forKey: .playcount)
        listeners = try? container.decode(Int.self, forKey: .listeners)
        
        if let tracksWrapper = try? container.decode(TracksWrapper.self, forKey: .tracks) {
            tracks = tracksWrapper.track
        } else {
            tracks = []
        }
        
        if let wikiWrapper = try? container.decode(WikiWrapper.self, forKey: .wiki) {
            wiki = wikiWrapper.summary
        } else {
            wiki = nil
        }
        
        if let imageArray = try? container.decode([AlbumImage].self, forKey: .images) {
            images = imageArray
        } else {
            images = nil
        }
    }
}

/// Wrapper structure for album tracks in the API response
struct TracksWrapper: Codable {
    let track: [AlbumTrack]
}

/// Wrapper structure for album wiki content in the API response
struct WikiWrapper: Codable {
    let summary: String
}

/// Represents an album image with its URL and size
struct AlbumImage: Codable {
    /// URL of the image
    let url: String
    /// Size descriptor (small, medium, large, extralarge)
    let size: String
    
    private enum CodingKeys: String, CodingKey {
        case url = "#text"
        case size
    }
}

/// Represents a track in an album
struct AlbumTrack: Codable {
    /// Track name
    let name: String
    /// Track duration in MM:SS format
    let duration: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case duration
    }
    
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

/// Main service class for Last.fm API interactions
@MainActor
class LastFMService {
    /// Shared singleton instance
    static let shared = LastFMService()
    /// Logger for debugging and error tracking
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "LastFMService")
    /// URL session for API requests
    private let session: URLSession
    /// ScrobbleKit manager instance
    private var manager: SBKManager?
    
    /// Private initializer to enforce singleton pattern
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
        setupScrobbleKit()
    }
    
    /// Sets up the ScrobbleKit manager with API credentials
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
        
        if let sessionKey = getStoredSessionKey() {
            manager?.setSessionKey(sessionKey)
            logger.info("Loaded existing Last.fm session key from keychain")
        }
    }
    
    // MARK: - Authentication
    
    /// Authenticates a user with Last.fm using their credentials
    /// - Parameters:
    ///   - username: Last.fm username
    ///   - password: Last.fm password
    /// - Throws: LastFMError if authentication fails
    func authenticate(username: String, password: String) async throws {
        guard let manager = manager else {
            throw LastFMError.configurationMissing
        }
        
        do {
            let response = try await manager.startSession(username: username, password: password)
            
            try await storeSessionKey(response.key)
            manager.setSessionKey(response.key)
            
            logger.info("Authentication successful")
        } catch {
            logger.error("Authentication failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Stores the session key securely in the keychain
    /// - Parameter key: The session key to store
    /// - Throws: LastFMError if storage fails
    private func storeSessionKey(_ key: String) async throws {
        let removeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lastfm_session_key"
        ]
        SecItemDelete(removeQuery as CFDictionary)
        
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
    
    /// Scrobbles a track to Last.fm
    /// - Parameter track: The track to scrobble
    /// - Throws: LastFMError if scrobbling fails
    public func scrobbleTrack(track: Track) async throws {
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
                timestamp: Date(),
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
    
    /// Updates the "Now Playing" status on Last.fm
    /// - Parameter track: The track currently playing
    /// - Throws: LastFMError if the update fails
    public func updateNowPlaying(track: Track) async throws {
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
    
    // MARK: - Album Information
    
    /// Retrieves detailed album information from Last.fm
    /// - Parameters:
    ///   - artist: The album artist
    ///   - album: The album name
    /// - Returns: Detailed album information
    /// - Throws: LastFMError if the request fails
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
    
    // MARK: - User Information
    
    /// Response structure for user information requests
    struct LastFMUserResponse: Codable {
        let user: LastFMUser
    }
    
    /// User information from Last.fm
    struct LastFMUser: Codable {
        let name: String
        let realname: String?
        let playcount: String
        let registered: LastFMRegistered
        let image: [AlbumImage]?
    }
    
    /// User registration information
    struct LastFMRegistered: Codable {
        let unixtime: String
    }
    
    /// Retrieves a user's registration timestamp
    /// - Parameter username: The Last.fm username
    /// - Returns: Unix timestamp of registration
    /// - Throws: LastFMError if the request fails
    public func getRegistrationTimestamp(username: String) async throws -> Int {
        guard let apiKey = SecureConfig.lastFMAPIKey else {
            throw LastFMError.missingApiKey
        }
        
        var components = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")
        components?.queryItems = [
            URLQueryItem(name: "method", value: "user.getInfo"),
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components?.url else {
            throw LastFMError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        let response = try decoder.decode(LastFMUserResponse.self, from: data)
        
        guard let timestamp = Int(response.user.registered.unixtime) else {
            throw LastFMError.invalidResponse
        }
        
        logger.debug("📅 Registration timestamp for \(username): \(timestamp)")
        return timestamp
    }
    
    /// Retrieves information about the authenticated user
    /// - Returns: User information from ScrobbleKit
    /// - Throws: LastFMError if the request fails
    public func getUserInfo() async throws -> SBKUser {
        guard let manager = manager else {
            throw LastFMError.configurationMissing
        }
        
        do {
            logger.debug("🔍 Fetching user information from Last.fm")
            let user = try await manager.getInfo()
            logger.info("✅ Successfully fetched user info for: \(user.username)")
            
            logger.debug("""
                👤 User Info Debug:
                Username: \(user.username)
                Real Name: \(user.realName ?? "N/A")
                Member Since: \(user.memberSince)
                Raw Member Since: \(user.memberSince.timeIntervalSince1970)
                Playcount: \(user.playcount)
                """)
            
            return user
            
        } catch {
            logger.error("❌ Failed to fetch user info: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Track Information
    
    /// Response structure for track information requests
    struct TrackInfoResponse: Codable {
        let track: TrackInfo
    }
    
    /// Detailed track information from Last.fm
    struct TrackInfo: Codable {
        let name: String
        let artist: TrackArtist
        let album: TrackAlbum?
        let duration: String?
        let url: String?
        
        private enum CodingKeys: String, CodingKey {
            case name, artist, album, duration, url
        }
    }
    
    /// Artist information within a track
    struct TrackArtist: Codable {
        let name: String
    }
    
    /// Album information within a track
    struct TrackAlbum: Codable {
        let title: String
        let artist: String
        let url: String?
        let image: [AlbumImage]?
    }
    
    /// Retrieves detailed track information from Last.fm
    /// - Parameters:
    ///   - artist: The track artist
    ///   - track: The track name
    /// - Returns: Detailed track information
    /// - Throws: LastFMError if the request fails
    func getTrackInfo(artist: String, track: String) async throws -> TrackInfo {
        guard let apiKey = SecureConfig.lastFMAPIKey else {
            throw LastFMError.missingApiKey
        }
        
        var components = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")
        components?.queryItems = [
            URLQueryItem(name: "method", value: "track.getInfo"),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "track", value: track),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components?.url else {
            throw LastFMError.invalidURL
        }
        
        logger.debug("🔍 Fetching track info for: \(track) by \(artist)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LastFMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LastFMError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(TrackInfoResponse.self, from: data)
            logger.info("✅ Successfully fetched track info for: \(result.track.name)")
            return result.track
        } catch {
            logger.error("❌ Failed to decode track info response: \(error.localizedDescription)")
            if let errorString = String(data: data, encoding: .utf8) {
                logger.debug("Response data: \(errorString)")
            }
            throw LastFMError.decodingError(error)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Converts a duration string in MM:SS format to total seconds
    /// - Parameter duration: Duration string in MM:SS format
    /// - Returns: Total seconds, or nil if conversion fails
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
    
    /// Sets the session key for the ScrobbleKit manager
    /// - Parameter key: The session key to set
    public func setSessionKey(_ key: String) {
        manager?.setSessionKey(key)
        logger.info("Set Last.fm session key (length: \(key.count) characters)")
    }
    
    /// Retrieves the stored session key from the keychain
    /// - Returns: The session key if found, nil otherwise
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
    
    /// Clears the current session and removes the session key from keychain
    @MainActor
    func clearSession() {
        manager?.setSessionKey("")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lastfm_session_key"
        ]
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Failed to remove session key from keychain: \(status)")
        } else {
            logger.info("Cleared Last.fm session and removed from keychain")
        }
    }
}
