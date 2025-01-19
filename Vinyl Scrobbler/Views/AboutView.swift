import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon and name
            VStack(spacing: 12) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(24)
                    .shadow(color: appState.currentTheme.artwork.shadow, radius: 8, y: 4)
                
                VStack(spacing: 4) {
                    Text(AppConfig.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(appState.currentTheme.foreground.primary)
                    
                    Text("Version \(AppConfig.version)")
                        .font(.system(size: 14))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                }
            }
            
            // Description
            Text(AppConfig.description)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(appState.currentTheme.foreground.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Credits
            VStack(spacing: 8) {
                Text("Created by")
                    .font(.system(size: 13))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                
                Text(AppConfig.author)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(appState.currentTheme.foreground.primary)
                
                Text("© \(AppConfig.year)")
                    .font(.system(size: 13))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
            }
            
            // Links
            VStack(spacing: 10) {
                LinkButton(
                    title: "Website",
                    icon: "link",
                    url: AppConfig.githubURL
                )
                .tint(appState.currentTheme.accent.primary)
                
                LinkButton(
                    title: "Last.fm",
                    icon: "music.note",
                    url: "https://www.last.fm"
                )
                .tint(appState.currentTheme.accent.primary)
                
                LinkButton(
                    title: "Discogs",
                    icon: "record.circle",
                    url: "https://www.discogs.com"
                )
                .tint(appState.currentTheme.accent.primary)
            }
        }
        .padding(24)
        .frame(width: 360, height: 600)
        .background(appState.currentTheme.background.primary)
    }
}

// MARK: - Link Button
struct LinkButton: View {
    @EnvironmentObject private var appState: AppState
    let title: String
    let icon: String
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
#Preview {
    AboutView()
        .environmentObject(AppState())
} 