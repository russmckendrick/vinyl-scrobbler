import SwiftUI

struct DiscogsSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @StateObject private var viewModel = DiscogsSearchViewModel()
    @State private var searchText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Search field
                SearchBar(text: $searchText, onCommit: performSearch)
                    .padding()
                
                if viewModel.isLoading {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.results.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else {
                    // Results list
                    List(viewModel.results) { result in
                        DiscogsResultRow(result: result)
                            .onTapGesture {
                                Task {
                                    await selectRelease(result)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Search Discogs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
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
    
    private func selectRelease(_ result: DiscogsSearchResponse.SearchResult) async {
        do {
            await viewModel.selectRelease(result)
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