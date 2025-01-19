import SwiftUI

struct DiscogsSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @StateObject private var viewModel = DiscogsSearchViewModel()
    @State private var input = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Load Album")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(appState.currentTheme.foreground.primary)
            
            // Search bar
            SearchBar(text: $input) {
                performSearch()
            }
            
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(appState.currentTheme.accent.primary)
            } else if viewModel.showResults {
                // Search results
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
                Text("Enter a Discogs release ID, URL, or search for an album")
                    .font(.caption)
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(appState.currentTheme.background.primary)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            viewModel.appState = appState
            if !appState.searchQuery.isEmpty {
                input = appState.searchQuery
                performSearch()
                appState.searchQuery = "" // Clear the query after using it
            }
        }
    }
    
    private func performSearch() {
        guard !input.isEmpty else { return }
        
        // Check if input might be a release ID or URL
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

#Preview {
    DiscogsSearchView()
        .environmentObject(AppState())
} 