import Foundation
import os
import AppKit
import Network

// MARK: - Models
struct DiscogsRelease: Codable {
    let id: Int
    let title: String
    let artists: [Artist]
    let tracklist: [Track]
    let year: Int?
    let images: [Image]?
    
    struct Artist: Codable {
        let name: String
    }
    
    struct Track: Codable {
        let position: String
        let title: String
        let duration: String?
    }
    
    struct Image: Codable {
        let uri: String
        let type: String
    }
}

// MARK: - Errors
enum DiscogsError: LocalizedError {
    case invalidInput
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case missingToken
    case releaseNotFound
    case connectionError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid input. Please provide a valid Discogs release URL or ID"
        case .invalidURL:
            return "Invalid URL for Discogs API request"
        case .invalidResponse:
            return "Invalid response from Discogs API"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode) from Discogs API"
        case .decodingError(let error):
            return "Failed to decode Discogs response: \(error.localizedDescription)"
        case .missingToken:
            return "Missing Discogs API token"
        case .releaseNotFound:
            return "Release not found on Discogs"
        case .connectionError(let message):
            return "Connection error: \(message)"
        }
    }
}

class DiscogsService {
    static let shared = DiscogsService()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "DiscogsService")
    private let session: URLSession
    private let userAgent = "VinylScrobbler/1.0 +https://github.com/russmckendrick/vinyl-scrobbler"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Authorization": "Discogs token=\(SecureConfig.discogsToken ?? "")"
        ]
        session = URLSession(configuration: config, delegate: DiscogsURLSessionDelegate(), delegateQueue: nil)
    }
    
    func extractReleaseId(from input: String) async throws -> String {
        // Check if input is already a release ID number
        if let _ = Int(input) {
            return input
        }
        
        // Check if input is a URL
        guard let url = URL(string: input),
              url.host == "www.discogs.com" || url.host == "discogs.com",
              url.pathComponents.count >= 3,
              url.pathComponents[1] == "release" else {
            throw DiscogsError.invalidInput
        }
        
        return url.pathComponents[2]
    }
    
    func loadRelease(_ releaseId: String) async throws -> DiscogsRelease {
        guard let url = URL(string: "https://api.discogs.com/releases/\(releaseId)") else {
            throw DiscogsError.invalidURL
        }
        
        logger.info("🎵 Fetching Discogs release: \(releaseId)")
        logger.debug("Request URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token = ConfigurationManager.shared.discogsToken {
            request.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization")
            logger.debug("Using Discogs token: \(String(token.prefix(8)))...")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ Invalid response type from Discogs API")
                throw DiscogsError.invalidResponse
            }
            
            logger.debug("Response status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error("❌ HTTP error \(httpResponse.statusCode) from Discogs API")
                if let errorString = String(data: data, encoding: .utf8) {
                    logger.error("Error response: \(errorString)")
                }
                throw DiscogsError.httpError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let release = try decoder.decode(DiscogsRelease.self, from: data)
            
            // Log release details
            logger.info("✅ Successfully loaded release: \(release.title)")
            logger.debug("""
                Release details:
                - ID: \(release.id)
                - Title: \(release.title)
                - Artist(s): \(release.artists.map { $0.name }.joined(separator: ", "))
                - Year: \(release.year ?? 0)
                - Number of tracks: \(release.tracklist.count)
                - Has artwork: \(release.images?.isEmpty == false ? "Yes" : "No")
                """)
            
            // Log track details
            logger.debug("Track listing:")
            for (index, track) in release.tracklist.enumerated() {
                logger.debug("""
                    Track \(index + 1):
                    - Position: \(track.position)
                    - Title: \(track.title)
                    - Duration: \(track.duration ?? "Not specified")
                    """)
            }
            
            return release
        } catch let decodingError as DecodingError {
            logger.error("❌ Failed to decode Discogs response: \(decodingError)")
            throw DiscogsError.decodingError(decodingError)
        } catch {
            logger.error("❌ Network error loading release: \(error.localizedDescription)")
            throw DiscogsError.connectionError(error.localizedDescription)
        }
    }
    
    func fetchImage(url: URL) async throws -> NSImage? {
        do {
            let (data, response) = try await self.session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("Invalid response type")
                throw DiscogsError.invalidResponse
            }
            
            self.logger.info("Received response with status code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                if let image = NSImage(data: data) {
                    return image
                }
                self.logger.error("Failed to create image from data")
                throw DiscogsError.decodingError(NSError(domain: "DiscogsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]))
            default:
                self.logger.error("Unexpected status code: \(httpResponse.statusCode)")
                throw DiscogsError.httpError(httpResponse.statusCode)
            }
        } catch {
            self.logger.error("Network error: \(error.localizedDescription)")
            throw DiscogsError.connectionError(error.localizedDescription)
        }
    }
}

// Custom URLSession delegate to handle SSL/TLS validation
class DiscogsURLSessionDelegate: NSObject, URLSessionDelegate {
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "DiscogsURLSessionDelegate")
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, 
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        
        // Only proceed with certificate validation for api.discogs.com
        if host == "api.discogs.com" {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            self.logger.info("Validated SSL certificate for api.discogs.com")
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            self.logger.error("Invalid host for SSL validation: \(host)")
        }
    }
}
