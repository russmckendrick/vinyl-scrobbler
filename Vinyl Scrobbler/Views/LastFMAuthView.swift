/// LastFMAuthView: A SwiftUI view that handles Last.fm authentication flow redirection.
/// This view acts as a bridge between the authentication trigger and the settings view,
/// automatically redirecting users to the Account settings tab where they can complete
/// the Last.fm authentication process.
import SwiftUI

/// A view that manages Last.fm authentication flow by redirecting to settings
struct LastFMAuthView: View {
    /// Environment variable to dismiss the current view
    @Environment(\.dismiss) private var dismiss
    /// Access to the global app state for managing authentication and settings state
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        EmptyView()
            .onAppear {
                // Redirect authentication flow to settings
                // This provides a more integrated experience by showing auth options
                // directly in the Account settings tab
                appState.showLastFMAuth = false
                appState.showSettings = true
                dismiss()
            }
    }
}

/// Preview provider for LastFMAuthView
#Preview {
    LastFMAuthView()
        .environmentObject(AppState())
}