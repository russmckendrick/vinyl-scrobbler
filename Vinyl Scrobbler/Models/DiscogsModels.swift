import Foundation

// MARK: - Search Response
struct DiscogsSearchResponse: Codable {
    let pagination: Pagination
    let results: [DiscogsSearchResult]
}

// MARK: - Pagination
struct Pagination: Codable {
    let page: Int
    let pages: Int
    let items: Int
}

// MARK: - Search Result
struct DiscogsSearchResult: Identifiable, Codable {
    let id: Int
    let title: String
    let year: String?
    let label: [String]?
    let type: String?
    let format: [String]?
    let thumb: String?
    let country: String?
}

// MARK: - Release
struct DiscogsRelease: Codable {
    let id: Int
    let title: String
    let artists: [Artist]
    let tracklist: [Track]
    let images: [Image]?
    let year: String?
    let country: String?
    let formats: [Format]?
    
    struct Artist: Codable {
        let name: String
        let id: Int?
    }
    
    struct Track: Codable {
        let position: String
        let title: String
        let duration: String?
    }
    
    struct Image: Codable {
        let type: String?
        let uri: String
        let resourceUrl: String
        let uri150: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case uri
            case resourceUrl = "resource_url"
            case uri150 = "uri150"
        }
    }
    
    struct Format: Codable {
        let name: String
        let qty: String?
        let descriptions: [String]?
    }
} 