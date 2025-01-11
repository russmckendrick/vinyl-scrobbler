import SwiftUI

struct DiscogsResultRow: View {
    let result: DiscogsSearchResult
    
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
            }
            .frame(width: 50, height: 50)
            .cornerRadius(4)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let year = result.year {
                        Text(year)
                            .foregroundColor(.secondary)
                    }
                    
                    if let format = result.format?.first {
                        Text(format)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }
            
            Spacer()
            
            // Add button
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.accentColor)
                .font(.title2)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    DiscogsResultRow(result: DiscogsSearchResult(
        style: ["Rock", "Alternative"],
        thumb: nil,
        title: "Sample Album",
        country: "US",
        format: ["Vinyl", "LP"],
        uri: "/release/1-Sample-Album",
        community: Community(want: 100, have: 50),
        label: ["Sample Label"],
        catno: "ABC-123",
        year: "2023",
        genre: ["Rock"],
        resourceUrl: "https://api.discogs.com/releases/1",
        type: "release",
        id: 1,
        barcode: ["123456789"],
        masterUrl: nil,
        masterId: nil,
        formatQuantity: 1,
        coverImage: nil,
        formats: [DiscogsSearchResult.Format(
            name: "Vinyl",
            qty: "1",
            text: "180 Gram",
            descriptions: ["LP", "Album"]
        )]
    ))
    .padding()
} 