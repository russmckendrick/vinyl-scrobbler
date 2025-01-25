/// DiscogsSearchViewModel: A view model that manages the search functionality for Discogs releases.
/// This class handles searching for vinyl releases, processing search results, and managing the UI state
/// for the search interface.
import SwiftUI
import OSLog

/// Main view model for Discogs search functionality
@MainActor
class DiscogsSearchViewModel: ObservableObject {
    /// Array of search results from Discogs
    @Published var results: [DiscogsSearchResponse.SearchResult] = []
    /// Loading state indicator for search operations
    @Published var isLoading = false
    /// Current search text input
    @Published var searchText = ""
    /// Flag to control the visibility of search results
    @Published var showResults = false
    /// Error message to display when search operations fail
    @Published var errorMessage: String?
    
    /// Logger instance for debugging and error tracking
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "DiscogsSearchViewModel")
    /// Shared instance of the Discogs service for API interactions
    private let discogsService = DiscogsService.shared
    /// Shared instance of the Last.fm service for additional metadata
    private let lastFMService = LastFMService.shared
    /// Reference to the global app state
    var appState: AppState?
    
    /// Loads a release by its ID
    func loadReleaseById(_ input: String) async throws {
        guard let appState = appState else { return }
        
        // Extract release ID from input
        let releaseId = try await discogsService.extractReleaseId(from: input)
        let release = try await discogsService.loadRelease(releaseId)
        appState.currentRelease = release
        appState.loadRelease(release)
    }
    
    /// Loads a release from a search result
    func loadRelease(_ result: DiscogsSearchResponse.SearchResult) async {
        guard let appState = appState else { return }
        
        do {
            let release = try await discogsService.loadRelease(result.id)
            appState.currentRelease = release
            appState.loadRelease(release)
        } catch {
            print("Failed to load release: \(error.localizedDescription)")
        }
    }
    
    /// Loads a release from a URL
    func loadReleaseFromURL(_ url: URL) async {
        guard let appState = appState else { return }
        
        do {
            let releaseId = try await discogsService.extractReleaseId(from: url.absoluteString)
            let release = try await discogsService.loadRelease(releaseId)
            appState.currentRelease = release
            appState.loadRelease(release)
        } catch {
            print("Failed to load release from URL: \(error.localizedDescription)")
        }
    }
    
    /// Performs a search for vinyl releases on Discogs
    /// - Parameter query: The search query string
    /// - Throws: Error if the search operation fails
    /// This method supports two search formats:
    /// 1. Artist - Album format (e.g., "The Beatles - Abbey Road")
    /// 2. General search terms
    func search(query: String) async throws {
        guard !query.isEmpty else { return }
        
        // Check if query contains artist - album format
        if query.contains("-") {
            let components = query.split(separator: "-").map(String.init)
            if components.count == 2 {
                let artist = components[0].trimmingCharacters(in: .whitespaces)
                let album = components[1].trimmingCharacters(in: .whitespaces)
                let parameters = DiscogsService.SearchParameters(
                    query: "",
                    type: "release",
                    title: nil,
                    releaseTitle: album,
                    artist: artist,
                    format: "vinyl"
                )
                let response = try await discogsService.searchReleases(parameters)
                filterAndUpdateResults(response)
                return
            }
        }
        
        // General search
        let parameters = DiscogsService.SearchParameters(
            query: query,
            type: "release",
            format: "vinyl"
        )
        
        let response = try await discogsService.searchReleases(parameters)
        filterAndUpdateResults(response)
    }
    
    /// Filters and updates the search results to show only vinyl releases
    /// - Parameter response: The raw search response from Discogs
    /// This method filters results to include only vinyl, LP, or 12" formats
    private func filterAndUpdateResults(_ response: DiscogsSearchResponse) {
        // Filter results to only include vinyl releases
        results = response.results.filter { result in
            guard let formats = result.format else { return false }
            return formats.contains { format in
                format.lowercased().contains("vinyl") ||
                format.lowercased().contains("lp") ||
                format.lowercased().contains("12\"")
            }
        }
        
        showResults = true
    }
    
    /// Handles the selection of a specific release from the search results
    /// - Parameter result: The selected search result
    /// - Throws: Error if the release cannot be loaded or processed
    /// This method loads the full release details and creates tracks in the app state
    func selectRelease(_ result: DiscogsSearchResponse.SearchResult) async throws {
        guard let appState = appState else { return }
        
        let release = try await discogsService.loadRelease(result.id)
        appState.loadRelease(release)
    }
}