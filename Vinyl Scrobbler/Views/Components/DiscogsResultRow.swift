import SwiftUI

struct DiscogsResultRow: View {
    let result: DiscogsSearchResponse.SearchResult
    
    private var formattedDetails: String {
        var details: [String] = []
        if let year = result.year {
            details.append(year)
        }
        if let formats = result.format {
            // Filter out redundant format information
            let cleanedFormats = formats
                .filter { !$0.lowercased().contains("album") }  // Remove redundant "Album" entries
                .map { $0.replacingOccurrences(of: ", ", with: " ") }  // Clean up internal commas
            details.append(cleanedFormats.joined(separator: ", "))
        }
        if let country = result.country {
            details.append(country)
        }
        return details.joined(separator: " • ")
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: result.thumb ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(4)
            .background(Color.gray.opacity(0.1))
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(formattedDetails)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(Color.clear)
    }
}

#Preview {
    VStack {
        DiscogsResultRow(
            result: DiscogsSearchResponse.SearchResult(
                id: 1234567,
                title: "Sample Album Title",
                year: "2023",
                thumb: "https://example.com/thumb.jpg",
                format: ["Vinyl", "LP", "Album", "Limited Edition"],
                label: ["Sample Label"],
                type: "release",
                country: "UK"
            )
        )
        DiscogsResultRow(
            result: DiscogsSearchResponse.SearchResult(
                id: 1234568,
                title: "Another Album",
                year: "2023",
                thumb: nil,
                format: ["Vinyl", "12\"", "Album"],
                label: ["Sample Label"],
                type: "release",
                country: "US"
            )
        )
    }
    .frame(width: 400)
    .padding()
} 