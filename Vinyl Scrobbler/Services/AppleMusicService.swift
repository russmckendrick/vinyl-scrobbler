import Foundation
import MusicKit
import OSLog

/// Service class for interacting with Apple Music API via MusicKit
/// Currently focused on artwork retrieval using catalog data requests
@MainActor
class AppleMusicService {
    /// Shared singleton instance
    static let shared = AppleMusicService()
    
    /// Logger for debugging and error tracking
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "AppleMusicService")
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Request authorization for MusicKit if needed
    /// - Returns: Boolean indicating whether authorization was granted
    private func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        
        switch status {
        case .authorized:
            logger.info("✅ MusicKit authorization granted")
            return true
        case .denied:
            logger.error("❌ MusicKit authorization denied")
            return false
        case .restricted:
            logger.error("❌ MusicKit access restricted")
            return false
        case .notDetermined:
            logger.error("❌ MusicKit authorization not determined")
            return false
        @unknown default:
            logger.error("❌ Unknown MusicKit authorization status")
            return false
        }
    }
    
    /// Searches for an album and returns its artwork URL
    /// - Parameters:
    ///   - artist: The album artist
    ///   - album: The album title
    /// - Returns: URL to the highest quality artwork available
    func getAlbumArtwork(artist: String, album: String) async throws -> URL? {
        // Check current authorization status
        let currentStatus = MusicAuthorization.currentStatus
        
        // If not authorized, request authorization
        if currentStatus != .authorized {
            let authorized = await requestAuthorization()
            guard authorized else {
                throw AppleMusicError.unauthorized
            }
        }
        
        logger.info("🔍 Searching Apple Music for album: \(album) by \(artist)")
        
        // Create a search request for the album
        var searchRequest = MusicCatalogSearchRequest(
            term: "\(artist) \(album)",
            types: [Album.self]
        )
        searchRequest.limit = 5  // Limit results for faster response
        
        do {
            let response = try await searchRequest.response()
            
            // Find the best matching album
            if let matchingAlbum = response.albums.first(where: { searchAlbum in
                // Check if both artist and album names match (case-insensitive)
                let artistMatch = searchAlbum.artistName.lowercased() == artist.lowercased()
                let albumMatch = searchAlbum.title.lowercased() == album.lowercased()
                return artistMatch && albumMatch
            }) ?? response.albums.first {
                
                logger.info("✅ Found matching album: \(matchingAlbum.title)")
                
                // Get the highest quality artwork available
                if let artwork = matchingAlbum.artwork {
                    let maxDimension = max(artwork.maximumWidth, artwork.maximumHeight)
                    let url = artwork.url(width: maxDimension, height: maxDimension)
                    logger.info("✅ Found artwork URL with dimension: \(maxDimension)px")
                    return url
                }
            }
            
            logger.warning("⚠️ No artwork found for album")
            return nil
            
        } catch {
            logger.error("❌ Apple Music search failed: \(error.localizedDescription)")
            throw AppleMusicError.searchFailed(error)
        }
    }
}

/// Errors that can occur during Apple Music operations
enum AppleMusicError: LocalizedError {
    /// User has not authorized MusicKit
    case unauthorized
    /// Search request failed
    case searchFailed(Error)
    /// No matching album found
    case albumNotFound
    /// No artwork available for the album
    case artworkNotFound
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Apple Music authorization required"
        case .searchFailed(let error):
            return "Apple Music search failed: \(error.localizedDescription)"
        case .albumNotFound:
            return "Album not found on Apple Music"
        case .artworkNotFound:
            return "No artwork available for this album"
        }
    }
} 