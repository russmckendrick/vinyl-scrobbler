import SwiftUI

struct TrackListView: View {
    @EnvironmentObject private var appState: AppState
    @Namespace private var animation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar and track count
            HStack {
                Capsule()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.vertical, 8)
                
                Spacer()
                
                if !appState.tracks.isEmpty {
                    Text("\(appState.tracks.count) Tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            
            // Track list
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(appState.tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRow(track: track, isPlaying: appState.currentTrack?.id == track.id)
                                .background(index % 2 == 0 ? Color.black.opacity(0.3) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    appState.selectAndPlayTrack(track)
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .shadow(color: .black.opacity(0.2), radius: 15, y: -8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TrackRow: View {
    let track: Track
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Position and playing indicator
            HStack(spacing: 4) {
                if isPlaying {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                } else {
                    Text(track.position)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption.monospaced())
                }
            }
            .frame(width: 24, alignment: .leading)
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .foregroundColor(isPlaying ? .white : .white.opacity(0.9))
                    .font(.callout)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(track.duration ?? "--:--")
                .foregroundColor(.white.opacity(0.7))
                .font(.caption.monospaced())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isPlaying ? Color.white.opacity(0.1) : Color.clear)
    }
}

#Preview {
    TrackListView()
        .environmentObject(AppState())
        .frame(maxWidth: 400)
        .background(.black)
} 