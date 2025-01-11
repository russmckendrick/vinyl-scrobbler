import Foundation
import OSLog

@MainActor
class DiscogsService {
    static let shared = DiscogsService()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "DiscogsService")
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "VinylScrobbler/1.0",
            "Authorization": "Discogs token=\(SecureConfig.discogsToken ?? "")"
        ]
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - API Methods
    func loadRelease(_ id: Int) async throws -> DiscogsRelease {
        let url = URL(string: "https://api.discogs.com/releases/\(id)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscogsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DiscogsError.httpError(httpResponse.statusCode)
        }
        
        do {
            return try decoder.decode(DiscogsRelease.self, from: data)
        } catch {
            logger.error("Failed to decode Discogs release: \(error.localizedDescription)")
            logger.error("Error details: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                logger.debug("Response data: \(dataString)")
            }
            throw DiscogsError.decodingError(error)
        }
    }
    
    func searchReleases(_ query: String, page: Int = 1) async throws -> DiscogsSearchResponse {
        var components = URLComponents(string: "https://api.discogs.com/database/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "release"),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let url = components.url else {
            throw DiscogsError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscogsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DiscogsError.httpError(httpResponse.statusCode)
        }
        
        do {
            return try decoder.decode(DiscogsSearchResponse.self, from: data)
        } catch {
            logger.error("Failed to decode Discogs search response: \(error.localizedDescription)")
            logger.error("Error details: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                logger.debug("Response data: \(dataString)")
            }
            throw DiscogsError.decodingError(error)
        }
    }
    
    func extractReleaseId(from input: String) async throws -> Int {
        // First try to parse as a direct ID
        if let id = Int(input) {
            return id
        }
        
        // Try to parse as URL
        guard let url = URL(string: input) else {
            throw DiscogsError.invalidInput("Invalid URL or release ID format")
        }
        
        // Extract release ID from URL path
        let pathComponents = url.pathComponents
        
        // Look for "release" or "releases" in the path
        if let releaseIndex = pathComponents.firstIndex(where: { $0 == "release" || $0 == "releases" }),
           releaseIndex + 1 < pathComponents.count,
           let releaseId = Int(pathComponents[releaseIndex + 1]) {
            return releaseId
        }
        
        throw DiscogsError.invalidInput("Could not find release ID in URL")
    }
}

// MARK: - Error Handling
enum DiscogsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case missingToken
    case invalidInput(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for Discogs API request"
        case .invalidResponse:
            return "Invalid response from Discogs API"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode) from Discogs API"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .missingToken:
            return "Missing Discogs API token"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}
