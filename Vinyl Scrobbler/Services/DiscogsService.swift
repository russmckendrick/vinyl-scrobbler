import Foundation
import OSLog

@MainActor
class DiscogsService {
    static let shared = DiscogsService()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "DiscogsService")
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "VinylScrobbler/1.0",
            "Authorization": "Discogs token=\(SecureConfig.discogsToken ?? "")"
        ]
        session = URLSession(configuration: config)
    }
    
    // MARK: - API Methods
    func loadRelease(_ id: String) async throws -> DiscogsRelease {
        let url = URL(string: "https://api.discogs.com/releases/\(id)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscogsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DiscogsError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DiscogsRelease.self, from: data)
        } catch {
            logger.error("Failed to decode Discogs release: \(error.localizedDescription)")
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
            let decoder = JSONDecoder()
            return try decoder.decode(DiscogsSearchResponse.self, from: data)
        } catch {
            logger.error("Failed to decode Discogs search response: \(error.localizedDescription)")
            throw DiscogsError.decodingError(error)
        }
    }
}

// MARK: - Error Handling
enum DiscogsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case missingToken
    
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
        }
    }
}
