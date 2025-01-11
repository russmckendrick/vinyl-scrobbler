import SwiftUI
import OSLog

@MainActor
class DiscogsSearchViewModel: ObservableObject {
    @Published var results: [DiscogsSearchResponse.SearchResult] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var showResults = false
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "DiscogsSearchViewModel")
    private let discogsService = DiscogsService.shared
    private let lastFMService = LastFMService.shared
    var appState: AppState?
    
    func loadReleaseById(_ input: String) async throws {
        // Check for [r123456] format
        if input.hasPrefix("[r") && input.hasSuffix("]") {
            let start = input.index(input.startIndex, offsetBy: 2)
            let end = input.index(input.endIndex, offsetBy: -1)
            let releaseId = String(input[start..<end])
            if let id = Int(releaseId) {
                let release = try await discogsService.loadRelease(id)
                await appState?.createTracks(from: release)
                return
            }
        }
        
        // Try regular ID extraction
        let releaseId = try await discogsService.extractReleaseId(from: input)
        let release = try await discogsService.loadRelease(releaseId)
        await appState?.createTracks(from: release)
    }
    
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
    
    func selectRelease(_ result: DiscogsSearchResponse.SearchResult) async throws {
        guard let appState = appState else { return }
        
        let release = try await discogsService.loadRelease(result.id)
        await appState.createTracks(from: release)
    }
} 