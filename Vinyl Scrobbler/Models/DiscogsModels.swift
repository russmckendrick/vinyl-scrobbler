import Foundation

// MARK: - Search Response
struct DiscogsSearchResponse: Codable {
    let pagination: Pagination
    let results: [DiscogsSearchResult]
}

// MARK: - Pagination
struct Pagination: Codable {
    let perPage: Int
    let pages: Int
    let page: Int
    let items: Int
    let urls: PaginationUrls
    
    enum CodingKeys: String, CodingKey {
        case perPage = "per_page"
        case pages
        case page
        case items
        case urls
    }
}

struct PaginationUrls: Codable {
    let last: String?
    let next: String?
}

// MARK: - Search Result
struct DiscogsSearchResult: Identifiable, Codable {
    let style: [String]?
    let thumb: String?
    let title: String
    let country: String?
    let format: [String]?
    let uri: String
    let community: Community?
    let label: [String]?
    let catno: String?
    let year: String?
    let genre: [String]?
    let resourceUrl: String
    let type: String
    let id: Int
    let barcode: [String]?
    let masterUrl: String?
    let masterId: Int?
    let formatQuantity: Int?
    let coverImage: String?
    let formats: [Format]?
    
    enum CodingKeys: String, CodingKey {
        case style, thumb, title, country, format, uri, community, label, catno, year, genre
        case resourceUrl = "resource_url"
        case type, id, barcode, formats
        case masterUrl = "master_url"
        case masterId = "master_id"
        case formatQuantity = "format_quantity"
        case coverImage = "cover_image"
    }
    
    struct Format: Codable {
        let name: String
        let qty: String?
        let text: String?
        let descriptions: [String]?
    }
}

struct Community: Codable {
    let want: Int
    let have: Int
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
    let resourceUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artists
        case tracklist
        case images
        case year
        case country
        case formats
        case resourceUrl = "resource_url"
    }
    
    struct Artist: Codable {
        let name: String
        let id: Int?
        let resourceUrl: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case id
            case resourceUrl = "resource_url"
        }
    }
    
    struct Track: Codable {
        let position: String
        let title: String
        let duration: String?
        let type_: String?
        
        enum CodingKeys: String, CodingKey {
            case position
            case title
            case duration
            case type_ = "type"
        }
    }
    
    struct Image: Codable {
        let type: String?
        let uri: String
        let resourceUrl: String
        let uri150: String
        let width: Int?
        let height: Int?
        
        enum CodingKeys: String, CodingKey {
            case type
            case uri
            case resourceUrl = "resource_url"
            case uri150
            case width
            case height
        }
    }
    
    struct Format: Codable {
        let name: String
        let qty: String?
        let descriptions: [String]?
        let text: String?
    }
} 