import Foundation

struct DiscogsSearchResult: Identifiable, Codable {
    let id: Int
    let title: String
    let year: String?
    let label: [String]?
    let type: String?
    let format: [String]?
    let thumb: String?
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case year
        case label
        case type
        case format
        case thumb
        case country
    }
} 