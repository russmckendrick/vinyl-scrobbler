import Foundation

// MARK: - Models
struct DiscogsRelease: Codable {
    let id: Int
    let title: String
    let artists: [Artist]
    let tracklist: [Track]
    let year: Int?
    let images: [Image]?
    let uri: String?
    
    // Artist information from release
    struct Artist: Codable {
        let name: String
    }
    
    // Track information from release
    struct Track: Codable {
        let position: String
        let title: String
        let duration: String?
    }
    
    // Image information from release
    struct Image: Codable {
        let uri: String
        let type: String
    }
}

// Search response structure from Discogs API
struct DiscogsSearchResponse: Codable {
    let results: [SearchResult]
    let pagination: Pagination
    
    // Individual search result
    struct SearchResult: Codable {
        let id: Int
        let title: String
        let year: String?
        let thumb: String?
        let format: [String]?
        let label: [String]?
        let type: String
        let country: String?
    }
    
    // Pagination information
    struct Pagination: Codable {
        let page: Int
        let pages: Int
        let items: Int
    }
} 