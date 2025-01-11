import SwiftUI

struct DiscogsSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @StateObject private var viewModel = DiscogsSearchViewModel()
    @State private var searchText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            VStack(spacing: 16) {
                Text("Search Discogs")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                SearchBar(text: $searchText, onCommit: performSearch)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Results area
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.results.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView(
                        "Search Discogs",
                        systemImage: "magnifyingglass",
                        description: Text("Enter an album name to search")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.results) { result in
                                DiscogsResultRow(result: result)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        Task {
                                            await selectRelease(result)
                                        }
                                    }
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            viewModel.appState = appState
        }
    }
    
    private func performSearch() {
        Task {
            await viewModel.search(query: searchText)
        }
    }
    
    private func selectRelease(_ result: DiscogsSearchResult) async {
        do {
            try await viewModel.selectRelease(result)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    DiscogsSearchView()
        .environmentObject(AppState())
} 