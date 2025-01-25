import Foundation
import OSLog

/// A service class responsible for interacting with the Discogs API
/// Provides functionality for searching releases and retrieving detailed album information
/// Implements MainActor to ensure all UI updates happen on the main thread
@MainActor
class DiscogsService {
    /// Shared singleton instance of the DiscogsService
    static let shared = DiscogsService()
    
    /// Logger instance for tracking API interactions and debugging
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "DiscogsService")
    
    /// URLSession instance configured with Discogs API headers
    private let session: URLSession
    
    /// JSON decoder configured for Discogs API response format
    private let decoder: JSONDecoder
    
    /// User agent string identifying the app to Discogs API
    private let userAgent = "VinylScrobbler/1.0 +https://www.vinyl-scrobbler.app/"
    
    /// Reference to the app's state for updating UI-related information
    private var appState: AppState?
    
    /// Private initializer to enforce singleton pattern
    /// Sets up URLSession with required headers and configures JSON decoder
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
    
    /// Configures the service with a reference to the app's state
    /// - Parameter appState: The app's state manager instance
    func configure(with appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - API Methods
    
    /// Fetches detailed information about a specific release from Discogs
    /// - Parameter id: The Discogs release ID to fetch
    /// - Returns: A DiscogsRelease object containing the release details
    /// - Throws: DiscogsError if the request fails or response is invalid
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
    
    /// Structure defining the parameters available for searching Discogs releases
    /// Includes functionality for cleaning and formatting search terms
    struct SearchParameters {
        /// The main search query
        let query: String
        /// The type of item to search for (default: "release")
        var type: String = "release"
        /// The title to search for
        var title: String?
        /// The specific release title to search for
        var releaseTitle: String?
        /// The artist name to search for
        var artist: String?
        /// The record label to search for
        var label: String?
        /// The genre to filter by
        var genre: String?
        /// The style to filter by
        var style: String?
        /// The country of release to filter by
        var country: String?
        /// The release year to filter by
        var year: String?
        /// The format to filter by (e.g., "Vinyl", "CD")
        var format: String?
        /// The catalog number to search for
        var catno: String?
        /// The barcode to search for
        var barcode: String?
        /// A specific track to search for
        var track: String?
        /// The page number for pagination (default: 1)
        var page: Int = 1
        
        /// Returns a cleaned version of the search query
        /// Combines artist and title information when available
        var cleanedQuery: String {
            if let artist = artist, let title = title {
                return "\(artist) - \(Self.cleanupTitle(title))"
            } else if let artist = artist, let releaseTitle = releaseTitle {
                return "\(artist) - \(Self.cleanupTitle(releaseTitle))"
            } else {
                return Self.cleanupTitle(query)
            }
        }
        
        /// Returns a cleaned version of the title
        var cleanedTitle: String? {
            title.map(Self.cleanupTitle)
        }
        
        /// Returns a cleaned version of the release title
        var cleanedReleaseTitle: String? {
            releaseTitle.map(Self.cleanupTitle)
        }
        
        /// Returns a cleaned version of the artist name
        var cleanedArtist: String? {
            artist.map(Self.cleanupTitle)
        }
        
        /// Removes common suffixes and extra information from titles
        /// - Parameter title: The title to clean
        /// - Returns: A cleaned version of the title
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
            
            return cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// Searches for releases on Discogs using the provided search parameters
    /// - Parameter parameters: The search parameters to use
    /// - Returns: A DiscogsSearchResponse containing the search results
    /// - Throws: DiscogsError if the search fails
    func searchReleases(_ parameters: SearchParameters) async throws -> DiscogsSearchResponse {
        var components = URLComponents(string: "https://api.discogs.com/database/search")!
        var queryItems = [
            URLQueryItem(name: "q", value: parameters.cleanedQuery),
            URLQueryItem(name: "type", value: parameters.type),
            URLQueryItem(name: "page", value: String(parameters.page))
        ]
        
        // Add optional parameters if they exist
        if let title = parameters.cleanedTitle {
            queryItems.append(URLQueryItem(name: "title", value: title))
        }
        if let releaseTitle = parameters.cleanedReleaseTitle {
            queryItems.append(URLQueryItem(name: "release_title", value: releaseTitle))
        }
        if let artist = parameters.cleanedArtist {
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
    
    /// Convenience method for performing a simple search with just a query string
    /// - Parameters:
    ///   - query: The search query
    ///   - page: The page number (default: 1)
    /// - Returns: A DiscogsSearchResponse containing the search results
    func searchReleases(_ query: String, page: Int = 1) async throws -> DiscogsSearchResponse {
        let parameters = SearchParameters(query: query, page: page)
        return try await searchReleases(parameters)
    }
    
    /// Extracts a Discogs release ID from various input formats
    /// Supports direct IDs, [r123456] format, and Discogs URLs
    /// - Parameter input: The input string to parse
    /// - Returns: The extracted release ID
    /// - Throws: DiscogsError if the input format is invalid
    func extractReleaseId(from input: String) async throws -> Int {
        // First try to parse as a direct ID
        if let id = Int(input) {
            return id
        }
        
        // Check for [r123456] format
        if input.hasPrefix("[r") && input.hasSuffix("]") {
            let start = input.index(input.startIndex, offsetBy: 2)
            let end = input.index(input.endIndex, offsetBy: -1)
            let releaseId = String(input[start..<end])
            if let id = Int(releaseId) {
                return id
            }
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
           let releaseId = Int(pathComponents[releaseIndex + 1].split(separator: "-").first ?? "") {
            return releaseId
        }
        
        throw DiscogsError.invalidInput("Could not find release ID in URL")
    }
    
    /// Creates Track objects from a Discogs release
    /// Attempts to enhance track information with Last.fm data
    /// - Parameter release: The DiscogsRelease to process
    /// - Returns: An array of Track objects
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

/// Enumeration of possible errors that can occur when interacting with the Discogs API
enum DiscogsError: LocalizedError {
    /// Invalid input format for release ID or URL
    case invalidInput(String)
    /// Invalid URL construction for API request
    case invalidURL
    /// Invalid response type from API
    case invalidResponse
    /// HTTP error with status code
    case httpError(Int)
    /// Error decoding API response
    case decodingError(Error)
    /// Missing Discogs API token
    case missingToken
    /// Requested release not found
    case releaseNotFound
    /// Network or connection error
    case connectionError(String)
    
    /// Human-readable description of the error
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
