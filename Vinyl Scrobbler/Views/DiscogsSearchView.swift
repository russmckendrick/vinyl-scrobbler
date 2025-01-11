import SwiftUI

struct DiscogsSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: DiscogsSearchViewModel
    
    init() {
        // Create the view model with a temporary AppState
        // It will be updated in onAppear
        _viewModel = StateObject(wrappedValue: DiscogsSearchViewModel(appState: AppState()))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            searchHeader
                .padding()
            
            // Results list
            if viewModel.isLoading {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty && !viewModel.searchQuery.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.results, id: \.id) { result in
                            SearchResultRow(result: result) {
                                Task {
                                    await viewModel.selectRelease(result)
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Pagination controls
            if viewModel.showPagination {
                paginationControls
                    .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            // Update the ViewModel with the correct AppState
            viewModel.updateAppState(appState)
        }
    }
    
    private var searchHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search for albums...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task {
                        await viewModel.search()
                    }
                }
            
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.textBackgroundColor))
        }
    }
    
    private var paginationControls: some View {
        HStack {
            Button {
                Task {
                    await viewModel.previousPage()
                }
            } label: {
                Image(systemName: "chevron.left")
                Text("Previous")
            }
            .disabled(!viewModel.canGoToPreviousPage)
            
            Spacer()
            
            Text("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.nextPage()
                }
            } label: {
                Text("Next")
                Image(systemName: "chevron.right")
            }
            .disabled(!viewModel.canGoToNextPage)
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: DiscogsSearchResponse.SearchResult
    let onSelect: () -> Void
    
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
            
            // Add button
            Button(action: onSelect) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        }
    }
}

// MARK: - View Model
@MainActor
class DiscogsSearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var results: [DiscogsSearchResponse.SearchResult] = []
    @Published var isLoading = false
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let discogsService: DiscogsService
    private weak var appStateRef: AppState?
    
    private var appState: AppState? {
        appStateRef
    }
    
    init(appState: AppState, discogsService: DiscogsService = .shared) {
        self.appStateRef = appState
        self.discogsService = discogsService
    }
    
    var showPagination: Bool {
        !results.isEmpty && totalPages > 1
    }
    
    var canGoToPreviousPage: Bool {
        currentPage > 1
    }
    
    var canGoToNextPage: Bool {
        currentPage < totalPages
    }
    
    func search() async {
        guard !searchQuery.isEmpty else { return }
        
        isLoading = true
        currentPage = 1
        
        do {
            let response = try await discogsService.searchReleases(searchQuery, page: currentPage)
            results = response.results
            totalPages = response.pagination.pages
        } catch {
            showError(error)
        }
        
        isLoading = false
    }
    
    func nextPage() async {
        guard canGoToNextPage else { return }
        await loadPage(currentPage + 1)
    }
    
    func previousPage() async {
        guard canGoToPreviousPage else { return }
        await loadPage(currentPage - 1)
    }
    
    private func loadPage(_ page: Int) async {
        isLoading = true
        
        do {
            let response = try await discogsService.searchReleases(searchQuery, page: page)
            results = response.results
            currentPage = page
            totalPages = response.pagination.pages
        } catch {
            showError(error)
        }
        
        isLoading = false
    }
    
    func selectRelease(_ result: DiscogsSearchResponse.SearchResult) async {
        guard let appState = appState else { return }
        
        do {
            let release = try await discogsService.loadRelease(String(result.id))
            // Convert Discogs release to app tracks
            let tracks = release.tracklist.map { track in
                Track(
                    position: track.position,
                    title: track.title,
                    duration: track.duration,
                    artist: release.artists.first?.name ?? "",
                    album: release.title
                )
            }
            
            // Update app state
            withAnimation {
                appState.tracks = tracks
                appState.currentTrack = tracks.first
            }
        } catch {
            showError(error)
        }
    }
    
    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    func updateAppState(_ newAppState: AppState) {
        self.appStateRef = newAppState
    }
}

// MARK: - Preview
struct DiscogsSearchView_Previews: PreviewProvider {
    static var previews: some View {
        DiscogsSearchView()
            .environmentObject(AppState())
    }
} 