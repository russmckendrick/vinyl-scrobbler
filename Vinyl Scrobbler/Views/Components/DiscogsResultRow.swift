/// DiscogsResultRow: A SwiftUI view component that displays a single Discogs search result
/// in a consistent, visually appealing row format. This component is designed to be used
/// in a list of search results from the Discogs API.
import SwiftUI

/// A view that represents a single row in the Discogs search results list
struct DiscogsResultRow: View {
    /// The search result data to display
    let result: DiscogsSearchResponse.SearchResult
    /// The global app state for accessing theme and other shared data
    @EnvironmentObject private var appState: AppState
    
    /// Formats the release details into a human-readable string
    /// Combines year, formats, and country information with bullet point separators
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
            // Thumbnail image with fallback to music note icon
            AsyncImage(url: URL(string: result.thumb ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "music.note")
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                    .frame(width: 30, height: 30)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(4)
            .background(appState.currentTheme.background.secondary.opacity(0.1))
            
            // Release information stack
            VStack(alignment: .leading, spacing: 4) {
                // Release title
                Text(result.title)
                    .font(.headline)
                    .foregroundStyle(appState.currentTheme.foreground.primary)
                    .lineLimit(1)
                
                // Release details (year, format, country)
                Text(formattedDetails)
                    .font(.subheadline)
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(appState.currentTheme.foreground.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(appState.currentTheme.background.secondary)
        .cornerRadius(8)
    }
}

/// SwiftUI preview provider showing sample Discogs search results
#Preview {
    VStack {
        // Preview with thumbnail
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
        // Preview without thumbnail
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
    .environmentObject(AppState())
}