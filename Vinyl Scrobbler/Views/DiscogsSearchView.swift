/// DiscogsSearchView: A SwiftUI view that provides an interface for searching and loading
/// albums from Discogs. Supports searching by release ID, URL, or text query, and displays
/// results in a scrollable list. Handles loading states and error presentation.
import SwiftUI

/// A view that enables users to search for and select albums from Discogs
struct DiscogsSearchView: View {
    /// Environment variable to handle view dismissal
    @Environment(\.dismiss) private var dismiss
    /// Access to the global app state for theming and data
    @EnvironmentObject private var appState: AppState
    
    /// View model managing Discogs search functionality and results
    @StateObject private var viewModel = DiscogsSearchViewModel()
    /// Current search input text
    @State private var input = ""
    /// Flag controlling error alert visibility
    @State private var showingError = false
    /// Current error message to display
    @State private var errorMessage = ""
    /// Flag indicating whether a search is in progress
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Title header
            Text("Load Album")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(appState.currentTheme.foreground.primary)
            
            // Search input field with submit action
            SearchBar(text: $input) {
                performSearch()
            }
            
            // Content area showing either loading indicator, results, or help text
            if isLoading {
                // Loading state
                ProgressView()
                    .controlSize(.small)
                    .tint(appState.currentTheme.accent.primary)
            } else if viewModel.showResults {
                // Results list with lazy loading
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.results, id: \.id) { result in
                            DiscogsResultRow(result: result)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectRelease(result)
                                }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            } else {
                // Help text when no search has been performed
                Text("Enter a Discogs release ID, URL, or search for an album")
                    .font(.caption)
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
            }
        }
        // View styling and layout
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(appState.currentTheme.background.primary)
        // Error alert configuration
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // Initial setup and handling of existing search query
        .onAppear {
            viewModel.appState = appState
            if !appState.searchQuery.isEmpty {
                input = appState.searchQuery
                performSearch()
                appState.searchQuery = "" // Clear the query after using it
            }
        }
    }
    
    /// Performs a search based on the current input text
    /// Determines whether to treat input as a release ID/URL or as a search query
    private func performSearch() {
        guard !input.isEmpty else { return }
        
        // Detect if input is a release ID or URL based on format
        if input.contains("/") || input.contains("[r") || Int(input) != nil {
            loadRelease()
        } else {
            isLoading = true
            Task {
                do {
                    try await viewModel.search(query: input)
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    /// Attempts to load a specific release by ID or URL
    /// Dismisses the view on success, shows error on failure
    private func loadRelease() {
        isLoading = true
        Task {
            do {
                try await viewModel.loadReleaseById(input)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
    
    /// Handles the selection of a search result
    /// Loads the full release details and dismisses the view on success
    /// - Parameter result: The selected search result to load
    private func selectRelease(_ result: DiscogsSearchResponse.SearchResult) {
        isLoading = true
        Task {
            do {
                try await viewModel.selectRelease(result)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

/// Preview provider for DiscogsSearchView
#Preview {
    DiscogsSearchView()
        .environmentObject(AppState())
}