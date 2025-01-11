import Foundation
import OSLog

@MainActor
class DiscogsService {
    static let shared = DiscogsService()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "DiscogsService")
    private let session: URLSession
    private let decoder: JSONDecoder
    private let userAgent = "VinylScrobbler/1.0 +https://www.vinyl-scrobbler.app/"
    private var appState: AppState?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Authorization": "Discogs token=\(SecureConfig.discogsToken ?? "")"
        ]
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func configure(with appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - API Methods
    func loadRelease(_ id: Int) async throws -> DiscogsRelease {
        let url = URL(string: "https://api.discogs.com/releases/\(id)")!
        
        logger.info("🎵 Fetching Discogs release: \(id)")
        logger.debug("Request URL: \(url.absoluteString)")
        
        let (data, response) = try await session.data(from: url)
        
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
        
        do {
            let release = try decoder.decode(DiscogsRelease.self, from: data)
            
            // Set the Discogs URI in AppState
            appState?.discogsURI = release.uri
            
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
                - URI: \(release.uri ?? "N/A")
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
            if let dataString = String(data: data, encoding: .utf8) {
                logger.debug("Response data: \(dataString)")
            }
            throw DiscogsError.decodingError(decodingError)
        } catch {
            logger.error("❌ Network error loading release: \(error.localizedDescription)")
            throw DiscogsError.connectionError(error.localizedDescription)
        }
    }
    
    // MARK: - Search Parameters
    struct SearchParameters {
        let query: String
        var type: String = "release"
        var title: String?
        var releaseTitle: String?
        var artist: String?
        var label: String?
        var genre: String?
        var style: String?
        var country: String?
        var year: String?
        var format: String?
        var catno: String?
        var barcode: String?
        var track: String?
        var page: Int = 1
    }
    
    func searchReleases(_ parameters: SearchParameters) async throws -> DiscogsSearchResponse {
        var components = URLComponents(string: "https://api.discogs.com/database/search")!
        var queryItems = [
            URLQueryItem(name: "q", value: parameters.query),
            URLQueryItem(name: "type", value: parameters.type),
            URLQueryItem(name: "page", value: String(parameters.page))
        ]
        
        // Add optional parameters if they exist
        if let title = parameters.title {
            queryItems.append(URLQueryItem(name: "title", value: title))
        }
        if let releaseTitle = parameters.releaseTitle {
            queryItems.append(URLQueryItem(name: "release_title", value: releaseTitle))
        }
        if let artist = parameters.artist {
            queryItems.append(URLQueryItem(name: "artist", value: artist))
        }
        if let label = parameters.label {
            queryItems.append(URLQueryItem(name: "label", value: label))
        }
        if let genre = parameters.genre {
            queryItems.append(URLQueryItem(name: "genre", value: genre))
        }
        if let style = parameters.style {
            queryItems.append(URLQueryItem(name: "style", value: style))
        }
        if let country = parameters.country {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }
        if let year = parameters.year {
            queryItems.append(URLQueryItem(name: "year", value: year))
        }
        if let format = parameters.format {
            queryItems.append(URLQueryItem(name: "format", value: format))
        }
        if let catno = parameters.catno {
            queryItems.append(URLQueryItem(name: "catno", value: catno))
        }
        if let barcode = parameters.barcode {
            queryItems.append(URLQueryItem(name: "barcode", value: barcode))
        }
        if let track = parameters.track {
            queryItems.append(URLQueryItem(name: "track", value: track))
        }
        
        components.queryItems = queryItems
        
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
    
    // Convenience method for simple searches
    func searchReleases(_ query: String, page: Int = 1) async throws -> DiscogsSearchResponse {
        let parameters = SearchParameters(query: query, page: page)
        return try await searchReleases(parameters)
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
    
    private func createTracks(from release: DiscogsRelease) async throws -> [Track] {
        var tracks: [Track] = []
        logger.info("🎼 Processing Discogs release: \(release.title)")
        
        // Try to get Last.fm album info first for artwork and track durations
        var lastFmAlbumInfo: AlbumInfo? = nil
        if let artist = release.artists.first?.name {
            do {
                lastFmAlbumInfo = try await LastFMService.shared.getAlbumInfo(
                    artist: artist,
                    album: release.title
                )
                logger.info("✅ Got Last.fm album info with \(lastFmAlbumInfo?.tracks.count ?? 0) tracks")
            } catch {
                logger.error("❌ Failed to get Last.fm album info: \(error.localizedDescription)")
            }
        }
        
        // Process tracks
        for (index, trackInfo) in release.tracklist.enumerated() {
            let initialDuration = trackInfo.duration?.isEmpty ?? true ? nil : trackInfo.duration
            let lastFmDuration = lastFmAlbumInfo?.tracks.indices.contains(index) == true ? lastFmAlbumInfo?.tracks[index].duration : nil
            
            // Use Discogs duration if available, otherwise use Last.fm duration, finally fallback to "3:00"
            let finalDuration = initialDuration ?? lastFmDuration ?? "3:00"
            
            let track = Track(
                position: trackInfo.position,
                title: trackInfo.title,
                duration: finalDuration,
                artist: release.artists.first?.name ?? "",
                album: release.title,
                artworkURL: nil
            )
            
            let isDefaultDuration = finalDuration == "3:00"
            logger.debug("""
                Added track:
                - Position: \(track.position)
                - Title: \(track.title)
                - Duration: \(track.duration ?? "3:00")\(isDefaultDuration ? " (default)" : "")
                - Artist: \(track.artist)
                """)
            
            tracks.append(track)
        }
        
        logger.info("✅ Processed \(tracks.count) tracks from release")
        return tracks
    }
}

// MARK: - Error Handling
enum DiscogsError: LocalizedError {
    case invalidInput(String)
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case missingToken
    case releaseNotFound
    case connectionError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
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
