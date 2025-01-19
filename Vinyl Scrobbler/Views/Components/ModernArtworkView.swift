import SwiftUI

struct ModernArtworkView: View {
    let artwork: Image?
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let artwork = artwork {
                    artwork
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width - 40)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(
                            color: .black.opacity(0.25),
                            radius: 30,
                            x: 0,
                            y: 10
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.windowBackgroundColor))
                        .frame(width: geometry.size.width - 40)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }
                        .overlay(
                            Image(systemName: "opticaldisc")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary)
                        )
                        .shadow(
                            color: .black.opacity(0.25),
                            radius: 30,
                            x: 0,
                            y: 10
                        )
                }
            }
            .position(
                x: geometry.frame(in: .local).midX,
                y: geometry.frame(in: .local).midY
            )
        }
    }
} 