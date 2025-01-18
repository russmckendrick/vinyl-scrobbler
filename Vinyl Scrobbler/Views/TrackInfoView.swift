import SwiftUI

struct TrackInfoView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            if let track = appState.currentTrack {
                // Track position and duration
                HStack(spacing: 8) {
                    Text("#")
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                        .font(.system(size: 16, weight: .medium))
                    Text(track.position)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                    
                    Image(systemName: "clock")
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(track.duration ?? "--:--")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                }
                
                // Track title
                Text(track.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(appState.currentTheme.foreground.primary)
                    .multilineTextAlignment(.center)
                
                // Artist and Album with link
                HStack(spacing: 4) {
                    Text(track.artist)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                    
                    Text("-")
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                        .font(.system(size: 18, weight: .medium))
                    
                    Text(track.album)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                    
                    if appState.discogsURI != nil {
                        Button {
                            if let url = URL(string: appState.discogsURI!) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 14))
                                .foregroundStyle(appState.currentTheme.foreground.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No Track Selected")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

#Preview {
    let previewState = AppState()
    return TrackInfoView()
        .environmentObject(previewState)
        .frame(maxWidth: 400)
        .padding()
        .background(previewState.currentTheme.background.primary)
} 