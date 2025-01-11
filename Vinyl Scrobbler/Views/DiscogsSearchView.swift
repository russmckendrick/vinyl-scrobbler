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
            
            Text("Enter a Discogs release ID or URL")
                .foregroundColor(.secondary)
            
            TextField("e.g. 1055904 or https://www.discogs.com/release/1055904", text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(loadRelease)
            
            Button(action: loadRelease) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Load")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(input.isEmpty || isLoading)
            
            if !isLoading {
                Text("Tip: You can find the release ID or URL on Discogs.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 400)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            viewModel.appState = appState
        }
    }
    
    private func loadRelease() {
        guard !input.isEmpty else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                try await viewModel.loadReleaseById(input)
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
}

#Preview {
    DiscogsSearchView()
        .environmentObject(AppState())
} 