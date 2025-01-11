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
    
    func loadReleaseById(_ input: String) async {
        isLoading = true
        do {
            let releaseId = try await discogsService.extractReleaseId(from: input)
            let release = try await discogsService.loadRelease(releaseId)
            
            // Create tracks using AppState
            if let appState = appState {
                await appState.createTracks(from: release)
            }
            
            // Reset search
            searchText = ""
            showResults = false
            isLoading = false
            
        } catch {
            logger.error("Failed to load release: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func search(query: String) async {
        guard !query.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create search parameters with the query
            let parameters = DiscogsService.SearchParameters(
                query: query,
                type: "release"  // Only search for releases
            )
            
            let response = try await discogsService.searchReleases(parameters)
            results = response.results
            showResults = true
        } catch {
            logger.error("Search error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func selectRelease(_ result: DiscogsSearchResponse.SearchResult) async throws {
        guard let appState = appState else { return }
        
        let release = try await discogsService.loadRelease(result.id)
        
        // Get artwork URL from Last.fm
        let artworkURL = try? await getLastFMArtworkURL(artist: release.artists.first?.name ?? "", album: release.title)
        
        // Convert Discogs release to app tracks
        let tracks = release.tracklist.map { track in
            Track(
                position: track.position,
                title: track.title,
                duration: track.duration,
                artist: release.artists.first?.name ?? "",
                album: release.title,
                artworkURL: artworkURL
            )
        }
        
        // Update app state
        appState.tracks = tracks
        if let firstTrack = tracks.first {
            appState.selectAndPlayTrack(firstTrack)
        }
    }
    
    private func getLastFMArtworkURL(artist: String, album: String) async throws -> URL? {
        let albumInfo = try await lastFMService.getAlbumInfo(artist: artist, album: album)
        // Get the largest available image (they come in order: small, medium, large, extralarge, mega)
        return albumInfo.images?.last.flatMap { URL(string: $0.url) }
    }
} 