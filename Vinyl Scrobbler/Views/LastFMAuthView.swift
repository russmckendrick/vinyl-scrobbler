import SwiftUI

struct LastFMAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @State private var username = ""
    @State private var password = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    
    private let lastFMService = LastFMService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Sign in to Last.fm")
                .font(.title2)
                .fontWeight(.bold)
            
            // Error message if any
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Login form
            VStack(alignment: .leading, spacing: 8) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 250)
            
            // Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Sign In") {
                    authenticate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(username.isEmpty || password.isEmpty || isAuthenticating)
            }
        }
        .padding(24)
        .frame(width: 300)
        .onChange(of: username) { _, newValue in
            errorMessage = nil
        }
        .onChange(of: password) { _, newValue in
            errorMessage = nil
        }
    }
    
    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            do {
                let (sessionKey, _) = try await lastFMService.startSession(
                    username: username,
                    password: password
                )
                
                if let key = sessionKey {
                    // Store the session key securely
                    KeychainHelper.saveLastFMSessionKey(key)
                    
                    await MainActor.run {
                        dismiss()
                    }
                } else {
                    errorMessage = "Authentication failed. Please try again."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isAuthenticating = false
        }
    }
}

#Preview {
    LastFMAuthView()
        .environmentObject(AppState())
} 