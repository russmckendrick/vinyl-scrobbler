import SwiftUI

struct LastFMAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LastFMAuthViewModel()
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Sign in to Last.fm")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Authentication is required to scrobble your vinyl plays")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Login form
            VStack(spacing: 16) {
                // Username field
                TextField("Username", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .submitLabel(.next)
                
                // Password field
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await viewModel.login()
                        }
                    }
                
                // Error message
                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Login button
            Button {
                Task {
                    await viewModel.login()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading || !viewModel.isValid)
            
            // Last.fm signup link
            Link("Don't have an account? Sign up on Last.fm",
                 destination: URL(string: "https://www.last.fm/join")!)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(width: 320)
        .onChange(of: viewModel.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
}

// MARK: - View Model
@MainActor
class LastFMAuthViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var isAuthenticated = false
    
    private let lastFMService = LastFMService.shared
    
    var isValid: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    func login() async {
        guard isValid else { return }
        
        isLoading = true
        error = nil
        
        do {
            try await lastFMService.authenticate(username: username, password: password)
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Preview
struct LastFMAuthView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default state
            LastFMAuthView()
                .previewDisplayName("Default")
            
            // Loading state
            LastFMAuthView()
                .previewDisplayName("Loading")
                .transformEnvironment(\.self) { view in
                    if let viewModel = Mirror(reflecting: view).descendant("_viewModel") as? LastFMAuthViewModel {
                        viewModel.isLoading = true
                    }
                }
            
            // Error state
            LastFMAuthView()
                .previewDisplayName("Error")
                .transformEnvironment(\.self) { view in
                    if let viewModel = Mirror(reflecting: view).descendant("_viewModel") as? LastFMAuthViewModel {
                        viewModel.error = "Invalid username or password"
                    }
                }
        }
    }
} 