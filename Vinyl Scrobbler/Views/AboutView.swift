import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon and name
            VStack(spacing: 8) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(16)
                
                Text(AppConfig.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version \(AppConfig.version)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text(AppConfig.description)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Credits
            VStack(spacing: 16) {
                Text("Created by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(AppConfig.author)
                    .font(.headline)
                
                Text("© \(AppConfig.year)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Links
            VStack(spacing: 12) {
                Link(destination: URL(string: AppConfig.githubURL)!) {
                    HStack {
                        Image(systemName: "link")
                        Text("Website")
                    }
                }
                
                Link(destination: URL(string: "https://www.last.fm")!) {
                    HStack {
                        Image(systemName: "music.note")
                        Text("Last.fm")
                    }
                }
                
                Link(destination: URL(string: "https://www.discogs.com")!) {
                    HStack {
                        Image(systemName: "record.circle")
                        Text("Discogs")
                    }
                }
            }
            .buttonStyle(.bordered)
            
            // Close button
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 320)
        .fixedSize()
    }
}

// MARK: - Preview
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
} 