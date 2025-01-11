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
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    if let year = result.year {
                        Text(year)
                    }
                    if let format = result.format?.joined(separator: ", ") {
                        Text("•")
                        Text(format)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    DiscogsResultRow(result: DiscogsSearchResult(
        id: 1234,
        title: "Sample Album",
        year: "2024",
        label: ["Sample Label"],
        type: "release",
        format: ["Vinyl", "LP"],
        thumb: nil,
        country: "US"
    ))
    .padding()
} 