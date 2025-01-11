import SwiftUI

@MainActor
class DiscogsSearchViewModel: ObservableObject {
    @Published var results: [DiscogsSearchResult] = []
    @Published var isLoading = false
    
    private let discogsService = DiscogsService.shared
    var appState: AppState?
    
    func search(query: String) async {
        guard !query.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await discogsService.searchReleases(query, page: 1)
            results = response.results
        } catch {
            print("Search error: \(error.localizedDescription)")
        }
    }
    
    func selectRelease(_ result: DiscogsSearchResult) async throws {
        guard let appState = appState else { return }
        
        let release = try await discogsService.loadRelease(String(result.id))
        
        // Convert Discogs release to app tracks
        let tracks = release.tracklist.map { track in
            Track(
                position: track.position,
                title: track.title,
                duration: track.duration,
                artist: release.artists.first?.name ?? "",
                album: release.title,
                artworkURL: URL(string: result.thumb ?? "")
            )
        }
        
        // Update app state
        await MainActor.run {
            appState.tracks = tracks
            appState.currentTrack = tracks.first
        }
    }
} 