/// AboutView: A SwiftUI view that displays information about the application
/// including the app icon, version, description, credits, and external links.
/// This view follows the app's theming system and provides a consistent visual style.
import SwiftUI

/// The main about view displaying app information and external links
struct AboutView: View {
    /// Environment variable to handle view dismissal
    @Environment(\.dismiss) private var dismiss
    /// Access to the global app state for theming
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon and name section
            VStack(spacing: 12) {
                // App icon with shadow and corner radius
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(24)
                    .shadow(color: appState.currentTheme.artwork.shadow, radius: 8, y: 4)
                
                // App name and version
                VStack(spacing: 4) {
                    Text(AppConfig.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(appState.currentTheme.foreground.primary)
                    
                    Text("Version \(AppConfig.version)")
                        .font(.system(size: 14))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                }
            }
            
            // App description section
            Text(AppConfig.description)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(appState.currentTheme.foreground.secondary)
                .fixedSize(horizontal: false, vertical: true)  // Allow vertical growth
            
            // Credits section with author and copyright
            VStack(spacing: 8) {
                Text("Created by")
                    .font(.system(size: 13))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                
                Text(AppConfig.author)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(appState.currentTheme.foreground.primary)
                
                Text(" \(AppConfig.year)")
                    .font(.system(size: 13))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
            }
            
            // External links section
            VStack(spacing: 10) {
                // GitHub repository link
                LinkButton(
                    title: "Website",
                    icon: "link",
                    url: AppConfig.githubURL
                )
                .tint(appState.currentTheme.accent.primary)
                
                // Last.fm service link
                LinkButton(
                    title: "Last.fm",
                    icon: "music.note",
                    url: "https://www.last.fm"
                )
                .tint(appState.currentTheme.accent.primary)
                
                // Discogs service link
                LinkButton(
                    title: "Discogs",
                    icon: "record.circle",
                    url: "https://www.discogs.com"
                )
                .tint(appState.currentTheme.accent.primary)
            }
        }
        // Main view styling
        .padding(24)
        .frame(width: 360, height: 600)
        .background(appState.currentTheme.background.primary)
    }
}

// MARK: - Link Button
/// A custom button component for external links with consistent styling
struct LinkButton: View {
    /// Access to the global app state for theming
    @EnvironmentObject private var appState: AppState
    /// The text to display on the button
    let title: String
    /// The SF Symbol name for the button's icon
    let icon: String
    /// The URL to open when the button is clicked
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(width: 200)
            .padding(.vertical, 8)
            .foregroundStyle(appState.currentTheme.foreground.primary)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

// MARK: - Preview
/// Preview provider for the AboutView
#Preview {
    AboutView()
        .environmentObject(AppState())
}