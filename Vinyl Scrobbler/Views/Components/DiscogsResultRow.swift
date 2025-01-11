import SwiftUI

struct DiscogsResultRow: View {
    let result: DiscogsSearchResponse.SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.headline)
                .lineLimit(2)
            
            HStack(spacing: 8) {
                if let year = result.year {
                    Text(year)
                        .foregroundColor(.secondary)
                }
                
                if let format = result.format?.first {
                    Text(format)
                        .foregroundColor(.secondary)
                }
                
                if let country = result.country {
                    Text(country)
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DiscogsResultRow(
        result: DiscogsSearchResponse.SearchResult(
            id: 1234567,
            title: "Sample Album Title",
            year: "2023",
            thumb: "https://example.com/thumb.jpg",
            format: ["Vinyl", "LP", "Album"],
            label: ["Sample Label"],
            type: "release",
            country: "US"
        )
    )
    .frame(width: 300)
    .padding()
} 