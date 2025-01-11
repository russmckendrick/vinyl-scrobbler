import Foundation

struct DiscogsSearchResponse: Codable {
    let pagination: Pagination
    let results: [DiscogsSearchResult]
    
    struct Pagination: Codable {
        let page: Int
        let pages: Int
        let items: Int
    }
} 