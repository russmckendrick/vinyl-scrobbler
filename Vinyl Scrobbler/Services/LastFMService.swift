import Foundation
import OSLog
import CryptoKit
import ScrobbleKit

// MARK: - Error Handling
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
struct LastFMResponse: Codable {
    let album: AlbumInfo
}

struct AlbumInfo: Codable {
    let name: String
    let artist: String
    let url: URL?
    let playcount: Int?
    let listeners: Int?
    let tracks: [AlbumTrack]
    let wiki: String?
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

struct TracksWrapper: Codable {
    let track: [AlbumTrack]
}

struct WikiWrapper: Codable {
    let summary: String
}

struct AlbumImage: Codable {
    let url: String
    let size: String
    
    private enum CodingKeys: String, CodingKey {
        case url = "#text"
        case size
    }
}

struct AlbumTrack: Codable {
    let name: String
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
@MainActor
class LastFMService {
    static let shared = LastFMService()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "LastFMService")
    private let session: URLSession
    private var manager: SBKManager?
    
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
        setupScrobbleKit()
    }
    
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
    public func getUserInfo() async throws -> SBKUser {
        guard let manager = manager else {
            throw LastFMError.configurationMissing
        }
        
        do {
            logger.debug("🔍 Fetching user information from Last.fm")
            let user = try await manager.getInfo(forUser: nil)
            logger.info("✅ Successfully fetched user info for: \(user.username)")
            return user
        } catch {
            logger.error("❌ Failed to fetch user info: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Track Information
    struct TrackInfoResponse: Codable {
        let track: TrackInfo
    }
    
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
    
    struct TrackArtist: Codable {
        let name: String
    }
    
    struct TrackAlbum: Codable {
        let title: String
        let artist: String
        let url: String?
        let image: [AlbumImage]?
    }
    
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
    public func setSessionKey(_ key: String) {
        manager?.setSessionKey(key)
        logger.info("Set Last.fm session key (length: \(key.count) characters)")
    }
    
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
    
    @MainActor
    func clearSession() {
        manager?.setSessionKey("")
        
        // Remove session key from keychain
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
