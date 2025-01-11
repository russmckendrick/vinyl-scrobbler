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
    case notAuthenticated
    
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
        case .notAuthenticated:
            return "Not authenticated"
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
    static let shared = LastFMService()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "LastFMService")
    private let session: URLSession
    private var sessionKey: String?
    
    // MARK: - Initialization
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }
    
    // MARK: - Authentication
    // Authenticate user with Last.fm
    func authenticate(username: String, password: String) async throws {
        let params = [
            "method": "auth.getToken",
            "api_key": SecureConfig.lastFMAPIKey ?? "",
            "username": username,
            "password": password
        ]
        
        let response = try await makeRequest(params)
        logger.debug("Authentication response: \(response)")
        
        guard let token = response["token"] as? String else {
            throw LastFMError.invalidResponse
        }
        
        let sessionParams = [
            "method": "auth.getSession",
            "api_key": SecureConfig.lastFMAPIKey ?? "",
            "token": token
        ]
        
        let sessionResponse = try await makeRequest(sessionParams)
        logger.debug("Session response: \(sessionResponse)")
        
        guard let newSessionKey = sessionResponse["session"] as? String else {
            throw LastFMError.invalidResponse
        }
        
        self.sessionKey = newSessionKey
        logger.info("Authentication successful")
    }
    
    // MARK: - Scrobbling
    // Submit track play to Last.fm
    func scrobbleTrack(track: Track) async throws {
        guard let sessionKey = sessionKey else {
            throw LastFMError.notAuthenticated
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Create initial params as a constant
        let baseParams = [
            "method": "track.scrobble",
            "artist": track.artist,
            "track": track.title,
            "album": track.album,
            "timestamp": String(timestamp),
            "sk": sessionKey
        ]
        
        // Create mutable copy for optional parameters
        var params = baseParams
        
        // Add duration if available
        if let duration = track.durationSeconds {
            params["duration"] = String(duration)
        }
        
        let response = try await makeRequest(params)
        logger.debug("Scrobble response: \(response)")
    }
    
    // Update Now Playing information
    func updateNowPlaying(track: Track) async throws {
        guard let sessionKey = sessionKey else {
            throw LastFMError.notAuthenticated
        }
        
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": track.artist,
            "track": track.title,
            "album": track.album,
            "sk": sessionKey
        ]
        
        // Add duration if available
        if let duration = track.durationSeconds {
            params["duration"] = String(duration)
        }
        
        let response = try await makeRequest(params)
        logger.debug("Now playing update response: \(response)")
    }
    
    // Scrobble track with specific timestamp
    func scrobbleArtist(artist: String, track: String, album: String, duration: Int, timestamp: Date) async throws {
        guard let sessionKey = sessionKey else {
            throw LastFMError.notAuthenticated
        }
        
        // Create params as immutable since we're not modifying it
        let params = [
            "method": "track.scrobble",
            "artist": artist,
            "track": track,
            "album": album,
            "duration": String(duration),
            "timestamp": String(Int(timestamp.timeIntervalSince1970)),
            "sk": sessionKey
        ]
        
        let response = try await makeRequest(params)
        logger.debug("Scrobble response: \(response)")
    }
    
    // MARK: - Album Information
    // Fetch album details from Last.fm
    func getAlbumInfo(artist: String, album: String) async throws -> AlbumInfo {
        let params = [
            "method": "album.getInfo",
            "artist": artist,
            "album": album,
            "api_key": SecureConfig.lastFMAPIKey ?? "",
            "format": "json"
        ]
        
        let response = try await makeRequest(params)
        
        guard let albumData = response["album"] as? [String: Any] else {
            throw LastFMError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let jsonData = try JSONSerialization.data(withJSONObject: ["album": albumData])
        let albumInfo = try decoder.decode(AlbumInfoResponse.self, from: jsonData)
        return albumInfo.album
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
    func setSessionKey(_ key: String) {
        sessionKey = key
        logger.info("Set Last.fm session key (length: \(key.count) characters)")
    }
    
    // Retrieve stored session key from keychain
    func getStoredSessionKey() -> String? {
        return KeychainHelper.getLastFMSessionKey()
    }
    
    // Start new session with credentials
    func startSession(username: String, password: String) async throws -> (key: String?, name: String?) {
        let params = [
            "method": "auth.getToken",
            "api_key": SecureConfig.lastFMAPIKey ?? "",
            "username": username,
            "password": password
        ]
        
        let response = try await makeRequest(params)
        logger.debug("Authentication response: \(response)")
        
        guard let token = response["token"] as? String else {
            throw LastFMError.invalidResponse
        }
        
        let sessionParams = [
            "method": "auth.getSession",
            "api_key": SecureConfig.lastFMAPIKey ?? "",
            "token": token
        ]
        
        let sessionResponse = try await makeRequest(sessionParams)
        logger.debug("Session response: \(sessionResponse)")
        
        guard let newSessionKey = sessionResponse["session"] as? String else {
            throw LastFMError.invalidResponse
        }
        
        self.sessionKey = newSessionKey
        logger.info("✅ Successfully authenticated with Last.fm")
        return (newSessionKey, response["name"] as? String)
    }
    
    // Clear current session
    @MainActor
    func clearSession() {
        sessionKey = nil
        KeychainHelper.deleteLastFMSessionKey()
        logger.info("Cleared Last.fm session")
    }
    
    // MARK: - Private Helper Methods
    private func makeRequest(_ params: [String: String]) async throws -> [String: Any] {
        var components = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        components?.queryItems?.append(URLQueryItem(name: "format", value: "json"))
        
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
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LastFMError.invalidResponse
            }
            return json
        } catch {
            logger.error("Failed to decode Last.fm response: \(error.localizedDescription)")
            throw LastFMError.decodingError(error)
        }
    }
}

// MARK: - Response Types
private struct AlbumInfoResponse: Codable {
    let album: AlbumInfo
}
