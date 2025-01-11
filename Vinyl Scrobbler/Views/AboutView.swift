import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon and name
            VStack(spacing: 12) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(24)
                    .shadow(radius: 8, y: 4)
                
                VStack(spacing: 4) {
                    Text(AppConfig.name)
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Version \(AppConfig.version)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            // Description
            Text(AppConfig.description)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Credits
            VStack(spacing: 8) {
                Text("Created by")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Text(AppConfig.author)
                    .font(.system(size: 16, weight: .medium))
                
                Text("© \(AppConfig.year)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // Links
            VStack(spacing: 10) {
                LinkButton(
                    title: "Website",
                    icon: "link",
                    url: AppConfig.githubURL
                )
                
                LinkButton(
                    title: "Last.fm",
                    icon: "music.note",
                    url: "https://www.last.fm"
                )
                
                LinkButton(
                    title: "Discogs",
                    icon: "record.circle",
                    url: "https://www.discogs.com"
                )
            }
        }
        .padding(24)
        .frame(width: 360, height: 600)
    }
}

// MARK: - Link Button
struct LinkButton: View {
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
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

// MARK: - Preview
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
} 