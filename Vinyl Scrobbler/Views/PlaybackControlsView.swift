import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 24) {
            // Previous track button
            Button {
                appState.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(!appState.canPlayPrevious ? Color(nsColor: .disabledControlTextColor) : .white)
            .disabled(!appState.canPlayPrevious)
            
            // Play/Pause button
            Button {
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }
            .buttonStyle(.plain)
            .foregroundColor(appState.tracks.isEmpty ? Color(nsColor: .disabledControlTextColor) : .white)
            .disabled(appState.tracks.isEmpty)
            .shadow(color: .black.opacity(0.3), radius: 10)
            
            // Next track button
            Button {
                appState.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(!appState.canPlayNext ? Color(nsColor: .disabledControlTextColor) : .white)
            .disabled(!appState.canPlayNext)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PlaybackControlsView()
        .environmentObject(AppState())
        .frame(maxWidth: 400)
        .padding()
        .background(.black)
} 