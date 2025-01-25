import Foundation

/// Models for interacting with the Discogs API
/// These models represent the data structures used for vinyl record information

/// Represents a detailed release (album/record) from the Discogs database
/// Contains comprehensive information about a specific vinyl release including
/// its tracks, artists, and associated images
struct DiscogsRelease: Codable {
    /// Unique identifier for the release in the Discogs database
    let id: Int
    /// Full title of the release
    let title: String
    /// List of artists who contributed to this release
    let artists: [Artist]
    /// Complete track listing for the release
    let tracklist: [Track]
    /// Release year of the album (optional as some releases might not have this information)
    let year: Int?
    /// Collection of images associated with the release (album artwork, etc.)
    let images: [Image]?
    /// URI (Uniform Resource Identifier) for the release on Discogs
    let uri: String?
    
    /// Represents an artist associated with a release
    /// Contains basic artist information needed for display
    struct Artist: Codable {
        /// Name of the artist
        let name: String
    }
    
    /// Represents a single track from the release
    /// Contains detailed information about each song/track
    struct Track: Codable {
        /// Physical position of the track on the release (e.g., "A1", "B2")
        let position: String
        /// Title of the track
        let title: String
        /// Length of the track in a formatted string (optional)
        let duration: String?
        /// Type of the track entry (e.g., "track", "heading", "index")
        let type: String?
    }
    
    /// Represents an image associated with the release
    /// Used for album artwork and other visual elements
    struct Image: Codable {
        /// Direct URL to the image resource
        let uri: String
        /// Type of image (e.g., "primary", "secondary")
        let type: String
    }
}

/// Represents the response from a Discogs search API call
/// Contains both search results and pagination information
struct DiscogsSearchResponse: Codable {
    /// Array of search results matching the query
    let results: [SearchResult]
    /// Pagination information for navigating through multiple pages of results
    let pagination: Pagination
    
    /// Represents a single item in the search results
    /// Contains basic information about a release found in the search
    struct SearchResult: Codable {
        /// Unique identifier for the release
        let id: Int
        /// Title of the release
        let title: String
        /// Release year (optional, stored as string to handle various formats)
        let year: String?
        /// URL to a thumbnail image of the release
        let thumb: String?
        /// Array of format information (e.g., "Vinyl", "LP", "Album")
        let format: [String]?
        /// Array of record label names associated with the release
        let label: [String]?
        /// Type of the release (e.g., "release", "master")
        let type: String
        /// Country of origin for the release
        let country: String?
    }
    
    /// Contains information about the pagination of search results
    /// Used for implementing pagination in the UI
    struct Pagination: Codable {
        /// Current page number
        let page: Int
        /// Total number of available pages
        let pages: Int
        /// Total number of items across all pages
        let items: Int
    }
}