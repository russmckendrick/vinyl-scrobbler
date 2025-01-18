import SwiftUI

struct ModernArtworkView: View {
    let artwork: Image?
    @State private var isHovered: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let artwork = artwork {
                    artwork
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width)
                        .shadow(
                            color: .black.opacity(0.4),
                            radius: isHovered ? 30 : 20,
                            x: 0,
                            y: isHovered ? 10 : 5
                        )
                        .scaleEffect(isHovered ? 1.02 : 1.0)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.ultraThinMaterial)
                        .frame(width: geometry.size.width)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "opticaldisc")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                        )
                }
            }
            .position(
                x: geometry.frame(in: .local).midX,
                y: geometry.frame(in: .local).midY
            )
        }
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
} 